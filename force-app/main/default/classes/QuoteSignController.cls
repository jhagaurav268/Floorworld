public with sharing class QuoteSignController {
    
    private static final Integer MAX_FILE_SIZE = 10 * 1024 * 1024; // 10MB
    private static final Integer HTTP_TIMEOUT = 120000;
    private static final String SIGNATURE_FIELD_TYPE_ID = '8020000000000141';
    private static final String DEFAULT_RECIPIENT_EMAIL = 'gaurav@cloudsciencelabs.com';
    private static final String DEFAULT_RECIPIENT_NAME = 'Gaurav Jha';
    private static final String QUOTE_STATUS_SENT = 'Contract/ Quote Sent';
    
    public class ZohoSignException extends Exception {}
    
    @AuraEnabled
    public static String handleQuoteSign(Id quoteId) {
        try {
            if (quoteId == null) {
                throw new AuraHandledException('Quote ID cannot be null');
            }
            
            DocumentCreationResponse docResponse = createDocument(quoteId);
            
            Integer pageCount = getTotalPagesFromZoho(docResponse.requestId) - 1;
            
            submitDocumentForSignature(docResponse, pageCount);
            
            updateQuoteStatus(quoteId, docResponse.requestId);
            
            return 'Success: Quote sent for signature';
            
        } catch (Exception e) {
            System.debug('Error in handleQuoteSign: ' + e.getMessage());
            throw new AuraHandledException('Failed to process quote signature: ' + e.getMessage());
        }
    }
    
    public class DocumentCreationResponse {
        public String requestId { get; set; }
        public String actionId { get; set; }
        public String documentId { get; set; }
        
        public DocumentCreationResponse(String requestId, String actionId, String documentId) {
            this.requestId = requestId;
            this.actionId = actionId;
            this.documentId = documentId;
        }
    }
    
    private static DocumentCreationResponse createDocument(Id quoteId) {
        try {
            ContentVersion contentVersion = getQuoteContentVersion(quoteId);
            
            if (contentVersion.ContentSize > MAX_FILE_SIZE) {
                throw new AuraHandledException('File size exceeds 10MB limit');
            }
            
            Map<String, Object> requestPayload = buildRequestPayload();
            
            HttpResponse response = sendZohoCreateRequest(contentVersion, requestPayload);
            
            return parseDocumentCreationResponse(response);
            
        } catch (Exception e) {
            throw new ZohoSignException('Error creating document: ' + e.getMessage());
        }
    }
    
    private static ContentVersion getQuoteContentVersion(Id quoteId) {
        List<ContentDocumentLink> links = [
            SELECT ContentDocumentId
            FROM ContentDocumentLink
            WHERE LinkedEntityId = :quoteId
            LIMIT 1
        ];
        
        if (links.isEmpty()) {
            throw new AuraHandledException('No PDF file found attached to this Quote');
        }
        
        List<ContentVersion> contentVersions = [
            SELECT Title, VersionData, FileExtension, ContentSize
            FROM ContentVersion
            WHERE ContentDocumentId = :links[0].ContentDocumentId
            AND IsLatest = true
            LIMIT 1
        ];
        
        if (contentVersions.isEmpty()) {
            throw new AuraHandledException('No valid content version found');
        }
        
        return contentVersions[0];
    }
    
    private static Map<String, Object> buildRequestPayload() {
        Map<String, Object> action = new Map<String, Object>{
            'recipient_email' => DEFAULT_RECIPIENT_EMAIL,
            'recipient_name' => DEFAULT_RECIPIENT_NAME,
            'action_type' => 'SIGN'
        };
        
        Map<String, Object> request = new Map<String, Object>{
            'request_name' => 'Quote Signature Request',
            'actions' => new List<Object>{ action }
        };
        
        return new Map<String, Object>{ 'requests' => request };
    }
    
    private static HttpResponse sendZohoCreateRequest(ContentVersion cv, Map<String, Object> payload) {
        String boundary = '----boundary_' + String.valueOf(Crypto.getRandomInteger());
        String jsonPayload = JSON.serialize(payload);
        
        Blob requestBody = buildMultipartBody(cv, jsonPayload, boundary);
        
        HttpRequest req = new HttpRequest();
        req.setEndpoint('callout:Zoho/api/v1/requests');
        req.setMethod('POST');
        req.setHeader('Content-Type', 'multipart/form-data; boundary=' + boundary);
        req.setBodyAsBlob(requestBody);
        req.setTimeout(HTTP_TIMEOUT);
        
        HttpResponse response = new Http().send(req);
        
        if (response.getStatusCode() < 200 || response.getStatusCode() >= 300) {
            throw new ZohoSignException(
                'Zoho API Error: ' + response.getStatusCode() + ' - ' + response.getBody()
            );
        }
        
        return response;
    }
    
    private static Blob buildMultipartBody(ContentVersion cv, String jsonPayload, String boundary) {
        String lineEnd = '\r\n';
        
        String bodyHeader = 
            '--' + boundary + lineEnd +
            'Content-Disposition: form-data; name="data"' + lineEnd +
            'Content-Type: application/json' + lineEnd + lineEnd +
            jsonPayload + lineEnd +
            '--' + boundary + lineEnd +
            'Content-Disposition: form-data; name="file"; filename="' + 
            cv.Title + '.' + cv.FileExtension + '"' + lineEnd +
            'Content-Type: application/pdf' + lineEnd + lineEnd;
        
        String bodyFooter = lineEnd + '--' + boundary + '--';
        
        String combinedDataAsHex = 
            EncodingUtil.convertToHex(Blob.valueOf(bodyHeader)) + 
            EncodingUtil.convertToHex(cv.VersionData) + 
            EncodingUtil.convertToHex(Blob.valueOf(bodyFooter));
        
        return EncodingUtil.convertFromHex(combinedDataAsHex);
    }
    
    private static DocumentCreationResponse parseDocumentCreationResponse(HttpResponse response) {
        Map<String, Object> responseMap = (Map<String, Object>) JSON.deserializeUntyped(response.getBody());
        Map<String, Object> requestsMap = (Map<String, Object>) responseMap.get('requests');
        
        if (requestsMap == null) {
            throw new ZohoSignException('Invalid response format: missing requests data');
        }
        
        String requestId = (String) requestsMap.get('request_id');
        
        List<Object> actionsList = (List<Object>) requestsMap.get('actions');
        String actionId = null;
        if (actionsList != null && !actionsList.isEmpty()) {
            Map<String, Object> action = (Map<String, Object>) actionsList[0];
            actionId = (String) action.get('action_id');
        }
        
        List<Object> docFieldList = (List<Object>) requestsMap.get('document_fields');
        String documentId = null;
        if (docFieldList != null && !docFieldList.isEmpty()) {
            Map<String, Object> docField = (Map<String, Object>) docFieldList[0];
            documentId = (String) docField.get('document_id');
        }
        
        if (String.isBlank(requestId) || String.isBlank(actionId) || String.isBlank(documentId)) {
            throw new ZohoSignException('Missing required response data from Zoho API');
        }
        
        return new DocumentCreationResponse(requestId, actionId, documentId);
    }
    
    private static Integer getTotalPagesFromZoho(String requestId) {
        try {
            HttpRequest req = new HttpRequest();
            req.setEndpoint('callout:Zoho/api/v1/requests/' + requestId);
            req.setMethod('GET');
            req.setHeader('Accept', 'application/json');
            req.setTimeout(HTTP_TIMEOUT);
            
            HttpResponse response = new Http().send(req);
            
            if (response.getStatusCode() == 200) {
                Map<String, Object> responseMap = (Map<String, Object>) JSON.deserializeUntyped(response.getBody());
                Map<String, Object> requestsMap = (Map<String, Object>) responseMap.get('requests');
                
                if (requestsMap != null) {
                    List<Object> documentIds = (List<Object>) requestsMap.get('document_ids');
                    
                    if (documentIds != null && !documentIds.isEmpty()) {
                        Map<String, Object> firstDoc = (Map<String, Object>) documentIds[0];
                        
                        if (firstDoc.containsKey('total_pages')) {
                            Integer totalPages = (Integer) firstDoc.get('total_pages');
                            return totalPages != null ? totalPages : 1;
                        }
                    }
                }
            } else {
                System.debug('Warning: Could not retrieve page count. Status: ' + response.getStatusCode());
            }
        } catch (Exception e) {
            System.debug('Warning: Error getting total pages, defaulting to 1: ' + e.getMessage());
        }
        
        return 1; 
    }
    
    private static void submitDocumentForSignature(DocumentCreationResponse docResponse, Integer pageCount) {
        try {
            Map<String, Object> requestBody = buildSubmitRequestBody(docResponse, pageCount);
            
            HttpRequest req = new HttpRequest();
            req.setEndpoint('callout:Zoho/api/v1/requests/' + docResponse.requestId + '/submit');
            req.setMethod('POST');
            req.setHeader('Content-Type', 'application/json');
            req.setHeader('Accept', 'application/json');
            req.setBody(JSON.serialize(requestBody));
            req.setTimeout(HTTP_TIMEOUT);
            
            HttpResponse response = new Http().send(req);
            
            if (response.getStatusCode() < 200 || response.getStatusCode() >= 300) {
                throw new ZohoSignException(
                    'Submit Error: ' + response.getStatusCode() + ' - ' + response.getBody()
                );
            }
            
        } catch (Exception e) {
            throw new ZohoSignException('Error submitting document for signature: ' + e.getMessage());
        }
    }
    
    private static Map<String, Object> buildSubmitRequestBody(DocumentCreationResponse docResponse, Integer pageCount) {
        Map<String, Object> signatureField = new Map<String, Object>{
            'field_type_id' => SIGNATURE_FIELD_TYPE_ID,
            'field_type_name' => 'Signature',
            'action_id' => docResponse.actionId,
            'is_mandatory' => true,
            'field_name' => 'Signature',
            'field_label' => 'Signature',
            'field_category' => 'image',
            'description_tooltip' => '',
            'is_draggable' => false,
            'is_resizable' => true,
            'abs_width' => 115,
            'abs_height' => 20,
            'width' => '18.790850',
            'height' => '2.525253',
            'x_value' => '77.249884',
            'y_value' => '94.289047',
            'page_no' => pageCount,
            'document_id' => docResponse.documentId
        };
        
        Map<String, Object> action = new Map<String, Object>{
            'action_id' => docResponse.actionId,
            'fields' => new List<Object>{ signatureField },
            'verify_recipient' => false,
            'recipient_countrycode_iso' => '',
            'action_type' => 'SIGN',
            'cloud_provider_name' => 'Zoho Sign',
            'recipient_email' => DEFAULT_RECIPIENT_EMAIL,
            'send_completed_document' => true,
            'recipient_phonenumber' => '',
            'is_bulk' => false,
            'signing_order' => -1,
            'cloud_provider_id' => 10,
            'recipient_name' => DEFAULT_RECIPIENT_NAME,
            'delivery_mode' => 'EMAIL',
            'recipient_countrycode' => '',
            'deleted_fields' => new List<Object>()
        };
        
        return new Map<String, Object>{
            'requests' => new Map<String, Object>{
                'actions' => new List<Object>{ action },
                'deleted_actions' => new List<Object>(),
                'document_fields' => new List<Object>()
            }
        };
    }
    
    private static void updateQuoteStatus(Id quoteId, String requestId) {
        try {
            Quote quoteRecord = new Quote(
                Id = quoteId,
                Status = QUOTE_STATUS_SENT,
                Signed_Request_Id__c = requestId
            );
            
            update quoteRecord;
            
        } catch (Exception e) {
            System.debug('Warning: Could not update quote status: ' + e.getMessage());
        }
    }
}