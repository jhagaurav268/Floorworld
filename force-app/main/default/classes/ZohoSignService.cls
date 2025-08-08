public with sharing class ZohoSignService {
    
    private static final String DEFAULT_RECIPIENT_EMAIL = 'gaurav@cloudsciencelabs.com';
    private static final String DEFAULT_RECIPIENT_NAME = 'Gaurav Jha';
    private static final String REQUEST_NAME = 'Quote Signature Request';
    private static final Integer MAX_FILE_SIZE = 10 * 1024 * 1024; // 10MB
    private static final Integer TIMEOUT = 120000; // 2 minutes
    private static final String BOUNDARY_PREFIX = '----boundary_';
    private static final String LINE_END = '\r\n';
    
    private static final String FIELD_TYPE_NAME = 'Textfield';
    private static final String FIELD_NAME = 'SignerName';
    private static final String FIELD_CATEGORY = 'Text';
    private static final Integer DEFAULT_PAGE_NO = 0;
    private static final String DEFAULT_X_VALUE = '50';
    private static final String DEFAULT_Y_VALUE = '100';
    private static final String DEFAULT_WIDTH = '150';
    private static final String DEFAULT_HEIGHT = '30';
    
    /**
     * Main method to process quote signature workflow
     * @param quoteId The ID of the quote to be signed
     */
    public static void processQuoteSignature(Id quoteId) {
        try {
            ZohoSignResponse createResponse = createDocument(quoteId);
            
            submitDocumentForSignature(
                createResponse.requestId, 
                createResponse.actionId, 
                createResponse.documentId
            );
            
            System.debug(LoggingLevel.INFO, 'Quote signature process completed successfully for Quote ID: ' + quoteId);
            
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'Error in processQuoteSignature: ' + e.getMessage());
            throw e;
        }
    }
    
    /**
     * Creates a document in Zoho Sign
     * @param quoteId The ID of the quote
     * @return ZohoSignResponse containing the response data
     */
    private static ZohoSignResponse createDocument(Id quoteId) {
        try {
            ContentVersion pdfFile = getPdfFileFromQuote(quoteId);
            
            validateFileSize(pdfFile.ContentSize);
            
            String jsonPayload = buildCreateDocumentPayload();
            
            Blob requestBody = buildMultipartFormData(jsonPayload, pdfFile);
            
            HttpResponse response = makeCreateDocumentRequest(requestBody);
            
            return parseCreateDocumentResponse(response);
            
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'Error in createDocument: ' + e.getMessage());
            throw new AuraHandledException('Failed to create document in Zoho Sign: ' + e.getMessage());
        }
    }
    
    /**
     * Retrieves the PDF file associated with the quote
     * @param quoteId The ID of the quote
     * @return ContentVersion of the PDF file
     */
    private static ContentVersion getPdfFileFromQuote(Id quoteId) {
        List<ContentDocumentLink> links = [
            SELECT ContentDocumentId
            FROM ContentDocumentLink
            WHERE LinkedEntityId = :quoteId
            LIMIT 1
        ];
        
        if (links.isEmpty()) {
            throw new AuraHandledException('No PDF file found on this Quote.');
        }
        
        List<ContentVersion> contentVersions = [
            SELECT Title, VersionData, FileExtension, ContentSize
            FROM ContentVersion
            WHERE ContentDocumentId = :links[0].ContentDocumentId
            AND IsLatest = true
            LIMIT 1
        ];
        
        if (contentVersions.isEmpty()) {
            throw new AuraHandledException('No content version found for the PDF file.');
        }
        
        return contentVersions[0];
    }
    
    /**
     * Validates the file size
     * @param fileSize The size of the file in bytes
     */
    private static void validateFileSize(Integer fileSize) {
        if (fileSize > MAX_FILE_SIZE) {
            throw new AuraHandledException('File size exceeds 10MB limit');
        }
    }
    
    /**
     * Builds the JSON payload for creating a document
     * @return JSON string payload
     */
    private static String buildCreateDocumentPayload() {
        Map<String, Object> action = new Map<String, Object>{
            'recipient_email' => DEFAULT_RECIPIENT_EMAIL,
            'recipient_name' => DEFAULT_RECIPIENT_NAME,
            'action_type' => 'SIGN'
        };
        
        Map<String, Object> request = new Map<String, Object>{
            'request_name' => REQUEST_NAME,
            'actions' => new List<Object>{ action }
        };
        
        Map<String, Object> payloadWrapper = new Map<String, Object>{
            'requests' => request
        };
        
        return JSON.serialize(payloadWrapper);
    }
    
    /**
     * Builds multipart form data for the HTTP request
     * @param jsonPayload The JSON payload
     * @param pdfFile The PDF file content version
     * @return Blob containing the multipart form data
     */
    private static Blob buildMultipartFormData(String jsonPayload, ContentVersion pdfFile) {
        String boundary = BOUNDARY_PREFIX + String.valueOf(Crypto.getRandomInteger());
        
        String bodyHeader = buildBodyHeader(boundary, jsonPayload, pdfFile);
        String bodyFooter = LINE_END + '--' + boundary + '--';
        
        Blob bodyHeaderBlob = Blob.valueOf(bodyHeader);
        Blob bodyFooterBlob = Blob.valueOf(bodyFooter);
        
        return combineBlobs(new List<Blob>{
            bodyHeaderBlob,
            pdfFile.VersionData,
            bodyFooterBlob
        });
    }
    
    /**
     * Builds the header part of the multipart form data
     * @param boundary The boundary string
     * @param jsonPayload The JSON payload
     * @param pdfFile The PDF file content version
     * @return String containing the header
     */
    private static String buildBodyHeader(String boundary, String jsonPayload, ContentVersion pdfFile) {
        return '--' + boundary + LINE_END +
               'Content-Disposition: form-data; name="data"' + LINE_END +
               'Content-Type: application/json' + LINE_END + LINE_END +
               jsonPayload + LINE_END +
               '--' + boundary + LINE_END +
               'Content-Disposition: form-data; name="file"; filename="' + 
               pdfFile.Title + '.' + pdfFile.FileExtension + '"' + LINE_END +
               'Content-Type: application/pdf' + LINE_END + LINE_END;
    }
    
    /**
     * Makes the HTTP request to create a document
     * @param requestBody The request body as Blob
     * @return HttpResponse from the API call
     */
    private static HttpResponse makeCreateDocumentRequest(Blob requestBody) {
        String boundary = BOUNDARY_PREFIX + String.valueOf(Crypto.getRandomInteger());
        
        HttpRequest req = new HttpRequest();
        req.setEndpoint('callout:Zoho/api/v1/requests');
        req.setMethod('POST');
        req.setHeader('Content-Type', 'multipart/form-data; boundary=' + boundary);
        req.setBodyAsBlob(requestBody);
        req.setTimeout(TIMEOUT);
        
        HttpResponse response = new Http().send(req);
        
        System.debug(LoggingLevel.DEBUG, 'Zoho Sign Create Document Response Status: ' + response.getStatusCode());
        System.debug(LoggingLevel.DEBUG, 'Zoho Sign Create Document Response Body: ' + response.getBody());
        
        if (response.getStatusCode() != 200 && response.getStatusCode() != 201) {
            throw new AuraHandledException('Zoho Sign API Error: ' + response.getStatusCode() + ' - ' + response.getBody());
        }
        
        return response;
    }
    
    /**
     * Parses the create document response
     * @param response The HTTP response
     * @return ZohoSignResponse containing parsed data
     */
    private static ZohoSignResponse parseCreateDocumentResponse(HttpResponse response) {
        Map<String, Object> responseMap = (Map<String, Object>) JSON.deserializeUntyped(response.getBody());
        
        Map<String, Object> requestsMap = (Map<String, Object>) responseMap.get('requests');
        if (requestsMap == null) {
            throw new AuraHandledException('Invalid response format: missing requests object');
        }
        
        List<Object> actionsList = (List<Object>) requestsMap.get('actions');
        if (actionsList == null || actionsList.isEmpty()) {
            throw new AuraHandledException('Invalid response format: missing actions array');
        }
        
        Map<String, Object> firstAction = (Map<String, Object>) actionsList[0];
        String actionId = (String) firstAction.get('action_id');
        
        List<Object> docFieldList = (List<Object>) requestsMap.get('document_fields');
        if (docFieldList == null || docFieldList.isEmpty()) {
            throw new AuraHandledException('Invalid response format: missing document_fields array');
        }
        
        Map<String, Object> docField = (Map<String, Object>) docFieldList[0];
        String documentId = (String) docField.get('document_id');
        
        String requestId = (String) requestsMap.get('request_id');
        
        return new ZohoSignResponse(requestId, actionId, documentId);
    }
    
    /**
     * Submits the document for signature
     * @param requestId The request ID from create document response
     * @param actionId The action ID from create document response
     * @param documentId The document ID from create document response
     */
    private static void submitDocumentForSignature(String requestId, String actionId, String documentId) {
        try {
            String jsonPayload = buildSubmitDocumentPayload(actionId, documentId);
            
            HttpResponse response = makeSubmitDocumentRequest(requestId, jsonPayload);
            
            System.debug(LoggingLevel.INFO, 'Document submitted for signature successfully');
            
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'Error in submitDocumentForSignature: ' + e.getMessage());
            throw new AuraHandledException('Failed to submit document for signature: ' + e.getMessage());
        }
    }
    
    /**
     * Builds the JSON payload for submitting a document for signature
     * @param actionId The action ID
     * @param documentId The document ID
     * @return JSON string payload
     */
    private static String buildSubmitDocumentPayload(String actionId, String documentId) {
        Map<String, Object> field = new Map<String, Object>{
            'field_type_name' => FIELD_TYPE_NAME,
            'action_id' => actionId,
            'document_id' => documentId,
            'field_name' => FIELD_NAME,
            'field_category' => FIELD_CATEGORY,
            'page_no' => DEFAULT_PAGE_NO,
            'x_value' => DEFAULT_X_VALUE,
            'y_value' => DEFAULT_Y_VALUE,
            'width' => DEFAULT_WIDTH,
            'height' => DEFAULT_HEIGHT
        };
        
        Map<String, Object> action = new Map<String, Object>{
            'action_type' => 'SIGN',
            'recipient_email' => DEFAULT_RECIPIENT_EMAIL,
            'recipient_name' => DEFAULT_RECIPIENT_NAME,
            'verify_recipient' => false,
            'signing_order' => 0,
            'action_id' => actionId,
            'fields' => new List<Object>{ field }
        };
        
        Map<String, Object> body = new Map<String, Object>{
            'requests' => new Map<String, Object>{
                'actions' => new List<Object>{ action }
            }
        };
        
        return JSON.serialize(body);
    }
    
    /**
     * Makes the HTTP request to submit document for signature
     * @param requestId The request ID
     * @param jsonPayload The JSON payload
     * @return HttpResponse from the API call
     */
    private static HttpResponse makeSubmitDocumentRequest(String requestId, String jsonPayload) {
        String payload = 'data=' + EncodingUtil.urlEncode(jsonPayload, 'UTF-8');
        
        HttpRequest req = new HttpRequest();
        req.setEndpoint('callout:Zoho/api/v1/requests/' + requestId + '/submit');
        req.setMethod('POST');
        req.setHeader('Content-Type', 'application/x-www-form-urlencoded');
        req.setHeader('Accept', 'application/json');
        req.setBody(payload);
        req.setTimeout(TIMEOUT);
        
        HttpResponse response = new Http().send(req);
        
        System.debug(LoggingLevel.DEBUG, 'Submit Document Response Status: ' + response.getStatusCode());
        System.debug(LoggingLevel.DEBUG, 'Submit Document Response Body: ' + response.getBody());
        
        if (response.getStatusCode() != 200 && response.getStatusCode() != 201) {
            throw new AuraHandledException('Submit Document API Error: ' + response.getStatusCode() + ' - ' + response.getBody());
        }
        
        return response;
    }
    
    /**
     * Combines multiple blobs into a single blob
     * @param blobs List of blobs to combine
     * @return Combined blob
     */
    private static Blob combineBlobs(List<Blob> blobs) {
        String encodedString = '';
        for (Blob b : blobs) {
            encodedString += EncodingUtil.base64Encode(b);
        }
        return EncodingUtil.base64Decode(encodedString);
    }
    
    /**
     * Inner class to hold Zoho Sign response data
     */
    public class ZohoSignResponse {
        public String requestId { get; private set; }
        public String actionId { get; private set; }
        public String documentId { get; private set; }
        
        public ZohoSignResponse(String requestId, String actionId, String documentId) {
            this.requestId = requestId;
            this.actionId = actionId;
            this.documentId = documentId;
        }
    }
}