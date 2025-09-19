public with sharing class ZohoSignService {
    
    private static final Integer MAX_FILE_SIZE = 10 * 1024 * 1024; 
    private static final Integer HTTP_TIMEOUT = 120000;
    private static final String SIGNATURE_FIELD_TYPE_ID = '8020000000000141';
    
    public class ZohoSignException extends Exception {}
    
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
    
    public class SignatureRequest {
        public Id recordId { get; set; }
        public String recipientName { get; set; }
        public String recipientEmail { get; set; }
        public String requestName { get; set; }
        public String statusFieldName { get; set; }
        public String statusValue { get; set; }
        public String requestIdFieldName { get; set; }
        
        public SignatureRequest(Id recordId, String recipientName, String recipientEmail, 
                               String requestName, String statusFieldName, String statusValue, 
                               String requestIdFieldName) {
            this.recordId = recordId;
            this.recipientName = recipientName;
            this.recipientEmail = recipientEmail;
            this.requestName = requestName;
            this.statusFieldName = statusFieldName;
            this.statusValue = statusValue;
            this.requestIdFieldName = requestIdFieldName;
        }
    }
    
    private class PdfData {
        public Blob pdfBlob { get; set; }
        public String fileName { get; set; }
        public Integer fileSize { get; set; }
        
        public PdfData(Blob pdfBlob, String fileName) {
            this.pdfBlob = pdfBlob;
            this.fileName = fileName;
            this.fileSize = pdfBlob.size();
        }
    }
    
    public static String processDocumentForSignature(SignatureRequest signatureRequest) {
        try {
            if (signatureRequest.recordId == null) {
                throw new AuraHandledException('Record ID cannot be null');
            }
            
            DocumentCreationResponse docResponse = createDocument(signatureRequest);
            Integer pageCount = getTotalPagesFromZoho(docResponse.requestId) - 1;
            submitDocumentForSignature(docResponse, pageCount, signatureRequest.recipientName, signatureRequest.recipientEmail);
            updateRecordStatus(signatureRequest, docResponse.requestId);
            
            return 'Success: Document sent for signature';
            
        } catch (Exception e) {
            System.debug('Error in processDocumentForSignature: ' + e.getMessage());
            throw new AuraHandledException('Failed to process document signature: ' + e.getMessage());
        }
    }
    
    private static DocumentCreationResponse createDocument(SignatureRequest signatureRequest) {
        try {
            PdfData pdfData;

            String sObjectType = String.valueOf(signatureRequest.recordId.getSObjectType());
            
            if (sObjectType == 'Quote') {
                pdfData = renderQuotePdfData(signatureRequest.recordId);
            }else if (sObjectType == 'Order') {
                pdfData = renderOrderPdfData(signatureRequest.recordId);
            } else {
                throw new AuraHandledException('Unsupported record type for Zoho Sign: ' + sObjectType);
            }
            
            if (pdfData.fileSize > MAX_FILE_SIZE) {
                throw new AuraHandledException('File size exceeds 10MB limit');
            }
            
            Map<String, Object> requestPayload = buildRequestPayload(
                signatureRequest.recipientName, 
                signatureRequest.recipientEmail,
                signatureRequest.requestName
            );
            HttpResponse response = sendZohoCreateRequest(pdfData, requestPayload);
            
            return parseDocumentCreationResponse(response);
            
        } catch (Exception e) {
            throw new ZohoSignException('Error creating document: ' + e.getMessage());
        }
    }
    
    private static PdfData renderQuotePdfData(Id quoteId) {
        PageReference pdfPage = Page.QuotePDF;
        pdfPage.getParameters().put('id', String.valueOf(quoteId));
        
        Blob pdfBlob = pdfPage.getContentAsPDF();
        
        return new PdfData(pdfBlob, 'Quote.pdf');
    }
    
    private static PdfData renderOrderPdfData(Id orderId) {
        PageReference pdfPage = Page.SalesOrderPDF; 
        pdfPage.getParameters().put('id', String.valueOf(orderId));

        Blob pdfBlob = pdfPage.getContentAsPDF();

        return new PdfData(pdfBlob, 'Order.pdf');
    }

    private static Map<String, Object> buildRequestPayload(String recipientName, String recipientEmail, String requestName) {
        Map<String, Object> action = new Map<String, Object>{
            'recipient_email' => recipientEmail,
            'recipient_name' => recipientName,
            'action_type' => 'SIGN'
        };
        
        Map<String, Object> request = new Map<String, Object>{
            'request_name' => requestName,
            'actions' => new List<Object>{ action }
        };
        
        return new Map<String, Object>{ 'requests' => request };
    }
    
    private static HttpResponse sendZohoCreateRequest(PdfData pdfData, Map<String, Object> payload) {
        String boundary = '----boundary_' + String.valueOf(Crypto.getRandomInteger());
        String jsonPayload = JSON.serialize(payload);
        
        Blob requestBody = buildMultipartBody(pdfData, jsonPayload, boundary);
        
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
    
    private static Blob buildMultipartBody(PdfData pdfData, String jsonPayload, String boundary) {
        String lineEnd = '\r\n';
        
        String bodyHeader = 
            '--' + boundary + lineEnd +
            'Content-Disposition: form-data; name="data"' + lineEnd +
            'Content-Type: application/json' + lineEnd + lineEnd +
            jsonPayload + lineEnd +
            '--' + boundary + lineEnd +
            'Content-Disposition: form-data; name="file"; filename="' + 
            pdfData.fileName + '"' + lineEnd +
            'Content-Type: application/pdf' + lineEnd + lineEnd;
        
        String bodyFooter = lineEnd + '--' + boundary + '--';
        
        String combinedDataAsHex = 
            EncodingUtil.convertToHex(Blob.valueOf(bodyHeader)) + 
            EncodingUtil.convertToHex(pdfData.pdfBlob) + 
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
    
    private static void submitDocumentForSignature(DocumentCreationResponse docResponse, Integer pageCount, String recipientName, String recipientEmail) {
        try {
            Map<String, Object> requestBody = buildSubmitRequestBody(docResponse, pageCount, recipientName, recipientEmail);
            
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
    
    private static Map<String, Object> buildSubmitRequestBody(DocumentCreationResponse docResponse, Integer pageCount, String recipientName, String recipientEmail) {
        Map<String, Object> signatureFieldOtherCondition = new Map<String, Object>{
            'field_type_id' => SIGNATURE_FIELD_TYPE_ID,
            'field_type_name' => 'Signature',
            'action_id' => docResponse.actionId,
            'is_mandatory' => true,
            'field_name' => 'Signature',
            'field_label' => 'Signature',
            'field_category' => 'image',
            'is_draggable' => false,
            'is_resizable' => true,
            'abs_width' => 115,
            'abs_height' => 20,
            'width' => '20.486986',
            'height' => '2.553444',
            'x_value' => '17.338372',
            'y_value' => '84.076608',
            'page_no' => pageCount - 3,
            'document_id' => docResponse.documentId
        };
        
        Map<String, Object> signatureFieldTermsAndConditions = new Map<String, Object>{
            'field_type_id' => SIGNATURE_FIELD_TYPE_ID,
            'field_type_name' => 'Signature',
            'action_id' => docResponse.actionId,
            'is_mandatory' => true,
            'field_name' => 'Signature',
            'field_label' => 'Signature',
            'field_category' => 'image',
            'is_draggable' => false,
            'is_resizable' => true,
            'abs_width' => 115,
            'abs_height' => 20,
            'width' => '20.486986',
            'height' => '2.553444',
            'x_value' => '17.087882',
            'y_value' => '35.172211',
            'page_no' => pageCount,
            'document_id' => docResponse.documentId
        };
        
        Map<String, Object> action = new Map<String, Object>{
            'action_id' => docResponse.actionId,
            'fields' => new List<Object>{ signatureFieldOtherCondition, signatureFieldTermsAndConditions },
            'verify_recipient' => false,
            'action_type' => 'SIGN',
            'recipient_email' => recipientEmail,
            'recipient_name' => recipientName,
            'send_completed_document' => true,
            'delivery_mode' => 'EMAIL'
        };
        
        return new Map<String, Object>{
            'requests' => new Map<String, Object>{
                'actions' => new List<Object>{ action },
                'deleted_actions' => new List<Object>(),
                'document_fields' => new List<Object>()
            }
        };
    }
    
    private static void updateRecordStatus(SignatureRequest signatureRequest, String requestId) {
        try {
            String sObjectType = String.valueOf(signatureRequest.recordId.getSObjectType());
            
            Map<String, Object> fieldsToUpdate = new Map<String, Object>();
            fieldsToUpdate.put('Id', signatureRequest.recordId);
            fieldsToUpdate.put(signatureRequest.statusFieldName, signatureRequest.statusValue);
            fieldsToUpdate.put(signatureRequest.requestIdFieldName, requestId);
            
            if (sObjectType == 'Quote' || sObjectType == 'Order') {
                fieldsToUpdate.put('Decline_Reason__c', '');
            }
            
            SObject recordToUpdate = Schema.getGlobalDescribe().get(sObjectType).newSObject();
            
            for (String fieldName : fieldsToUpdate.keySet()) {
                recordToUpdate.put(fieldName, fieldsToUpdate.get(fieldName));
            }
            
            update recordToUpdate;
            
        } catch (Exception e) {
            System.debug('Warning: Could not update record status: ' + e.getMessage());
        }
    }
}