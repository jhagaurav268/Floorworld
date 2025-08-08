public with sharing class QuoteSignController {
    private static final String CLIENT_ID = '1000.FOPWH6JHBKI4HIXTYTHHEPEBT0JHLJ';
    private static final String CLIENT_SECRET = 'e99ea40c24a973015af9063ae2db1b6a091b19b4e3';
    private static final String REDIRECT_URI = 'https://www.google.com';
    private static final String REFRESH_TOKEN = '1000.9e3f5e1cfcaed78aa37bf08aa41dfd0f.c8c7c46915fff630988f5dae4df8b9f6';
    private static String ACCESS_TOKEN = '';
    
    public static String getZohoAccessToken() {
        Http http = new Http();
        HttpRequest request = new HttpRequest();
        String endpoint = 'https://accounts.zoho.com/oauth/v2/token';
        
        String body = 'client_id=' + EncodingUtil.urlEncode(CLIENT_ID, 'UTF-8') +
            '&client_secret=' + EncodingUtil.urlEncode(CLIENT_SECRET, 'UTF-8') +
            '&refresh_token=' + EncodingUtil.urlEncode(REFRESH_TOKEN, 'UTF-8') +
            '&grant_type=refresh_token' +
            '&redirect_uri=' + EncodingUtil.urlEncode(REDIRECT_URI, 'UTF-8');
        
        request.setEndpoint(endpoint);
        request.setMethod('POST');
        request.setHeader('Content-Type', 'application/x-www-form-urlencoded');
        request.setBody(body);
        HttpResponse response = http.send(request);
        try {
            if (response.getStatusCode() == 200) {
                Map<String, Object> resMap = (Map<String, Object>) JSON.deserializeUntyped(response.getBody());
                ACCESS_TOKEN = (String) resMap.get('access_token');
                return (String) resMap.get('access_token');
            } else {
                System.debug('Failed to fetch token. Status: ' + response.getStatus() + ', Body: ' + response.getBody());
                throw new AuraHandledException('You have made too many requests continuously. Please try again after some time');
            }
        } catch (Exception ex) {
            throw new AuraHandledException('You have made too many requests continuously. Please try again after some time');
        }
    }
    
    @AuraEnabled
    public static void handleQuoteSign(Id quoteId){
        getZohoAccessToken();
        String response = createDoc(quoteId);
        Map<String, Object> resultMap = (Map<String, Object>) JSON.deserializeUntyped(response);
        
        String requestId = (String) resultMap.get('request_id');
        String actionId = (String) resultMap.get('action_id');
        String documentId = (String) resultMap.get('document_id');
        System.debug('requestId ' + requestId);
        System.debug('actionId ' + actionId);
        System.debug('documentId ' + documentId);
        Integer pageCount = getTotalPagesFromZoho(requestId) - 1;
        System.debug('pageCount ' + pageCount);
        sendDocForSign(requestId, actionId, documentId, pageCount);
        updateQuoteWithSignatureDetails(quoteId, requestId);
    }
    
    public static String createDoc(Id quoteId) {
        try {
            // Get Quote data
            Quote quoteData = [
                SELECT Id, Account.Name, Email 
                FROM Quote 
                WHERE Id = :quoteId 
                LIMIT 1
            ];
            
            // Get attached PDF
            List<ContentDocumentLink> links = [
                SELECT ContentDocumentId
                FROM ContentDocumentLink
                WHERE LinkedEntityId = :quoteId
                LIMIT 1
            ];
            if (links.isEmpty()) {
                throw new AuraHandledException('No PDF file found on this Quote.');
            }
            
            ContentVersion cv = [
                SELECT Title, VersionData, FileExtension, ContentSize
                FROM ContentVersion
                WHERE ContentDocumentId = :links[0].ContentDocumentId
                AND IsLatest = true
                LIMIT 1
            ];
            
            if (cv.ContentSize > 10 * 1024 * 1024) {
                throw new AuraHandledException('File size exceeds 10MB limit');
            }
            
            // Build JSON payload
            Map<String, Object> action = new Map<String, Object>{
                'recipient_email' => quoteData.Email,
                    'recipient_name'  => quoteData.Account != null ? quoteData.Account.Name : 'Recipient',
                        'action_type'     => 'SIGN'
                        };
                            
                            Map<String, Object> request = new Map<String, Object>{
                                'request_name' => 'Quote Signature Request',
                                    'actions'      => new List<Object>{ action }
                            };
                                
                                Map<String, Object> payloadWrapper = new Map<String, Object>{
                                    'requests' => request
                                        };
                                            
                                            String jsonPayload = JSON.serialize(payloadWrapper);
            
            // Multipart boundary
            String boundary = '----boundary_' + String.valueOf(Math.abs(Crypto.getRandomInteger()));
            String lineEnd  = '\r\n';
            
            String jsonPart =
                '--' + boundary + lineEnd +
                'Content-Disposition: form-data; name="data"' + lineEnd +
                'Content-Type: application/json; charset=UTF-8' + lineEnd +
                lineEnd +
                jsonPayload + lineEnd;
            
            String filePart =
                '--' + boundary + lineEnd +
                'Content-Disposition: form-data; name="file"; filename="' + cv.Title + '.' + cv.FileExtension + '"' + lineEnd +
                'Content-Type: application/pdf' + lineEnd +
                'Content-Transfer-Encoding: binary' + lineEnd +
                lineEnd;
            
            String endPart = lineEnd + '--' + boundary + '--' + lineEnd;
            
            // Combine into final blob
            Blob bodyBlob = combineBlobs(new List<Blob>{
                Blob.valueOf(jsonPart),
                    Blob.valueOf(filePart),
                    cv.VersionData,
                    Blob.valueOf(endPart)
                    });
            
            // Send request
            HttpRequest req = new HttpRequest();
            req.setEndpoint('https://sign.zoho.com/api/v1/requests'); 
            req.setMethod('POST');
            req.setHeader('Authorization', 'Zoho-oauthtoken ' + ACCESS_TOKEN);
            req.setHeader('Content-Type', 'multipart/form-data; boundary=' + boundary);
            req.setBodyAsBlob(bodyBlob);
            req.setTimeout(120000);
            
            HttpResponse res = new Http().send(req);
            System.debug('Zoho Sign Response: ' + res.getBody());
            
            if (res.getStatusCode() != 200 && res.getStatusCode() != 201) {
                throw new AuraHandledException('Zoho Sign Error: ' + res.getStatusCode() + ' - ' + res.getBody());
            }
            
            // Parse response
            Map<String, Object> responseMap = (Map<String, Object>)JSON.deserializeUntyped(res.getBody());
            Map<String, Object> requestsMap = (Map<String, Object>)responseMap.get('requests');
            
            String requestId  = (String)requestsMap.get('request_id');
            String actionId   = '';
            String documentId = '';
            
            if (requestsMap.containsKey('actions')) {
                List<Object> actionsList = (List<Object>)requestsMap.get('actions');
                if (!actionsList.isEmpty()) {
                    Map<String, Object> act = (Map<String, Object>)actionsList[0];
                    actionId = (String)act.get('action_id');
                }
            }
            
            if (requestsMap.containsKey('document_fields')) {
                List<Object> docFieldList = (List<Object>)requestsMap.get('document_fields');
                if (!docFieldList.isEmpty()) {
                    Map<String, Object> docField = (Map<String, Object>)docFieldList[0];
                    documentId = (String)docField.get('document_id');
                }
            }
            
            return JSON.serialize(new Map<String, String>{
                'request_id'  => requestId,
                    'action_id'   => actionId,
                    'document_id' => documentId
                    });
            
        } catch (Exception e) {
            throw new AuraHandledException('Error sending quote: ' + e.getMessage());
        }
    }

    public static Integer getTotalPagesFromZoho(String requestId) {
        try {
            String endpoint = 'https://sign.zoho.com/api/v1/requests' + requestId;
            HttpRequest req = new HttpRequest();
            req.setEndpoint(endpoint);
            req.setMethod('GET');
            req.setHeader('Accept', 'application/json');
            req.setHeader('Authorization', 'Zoho-oauthtoken ' + ACCESS_TOKEN);
            req.setTimeout(120000);
            
            HttpResponse res = new Http().send(req);
            System.debug('Get Request Response: ' + res.getBody());
            
            if (res.getStatusCode() == 200) {
                Map<String, Object> responseMap = (Map<String, Object>)JSON.deserializeUntyped(res.getBody());
                
                Map<String, Object> requestsMap = (Map<String, Object>)responseMap.get('requests');
                
                if (requestsMap != null) {
                    List<Object> documentIds = (List<Object>)requestsMap.get('document_ids');
                    
                    if (documentIds != null && !documentIds.isEmpty()) {
                        Map<String, Object> firstDoc = (Map<String, Object>)documentIds[0];
                        
                        if (firstDoc.containsKey('total_pages')) {
                            return (Integer)firstDoc.get('total_pages');
                        }
                    }
                }
            } else {
                System.debug('Error getting request details: ' + res.getStatusCode() + ' - ' + res.getBody());
            }
        } catch (Exception e) {
            System.debug('Error getting total pages: ' + e.getMessage());
        }
        
        return 1;
    }
    
    public static void sendDocForSign(String requestId, String actionId, String documentId, Integer pageCount) {
        try {
            Map<String, Object> field = new Map<String, Object>{
                'field_type_id'      => '8020000000000141',
                    'field_type_name'    => 'Signature',
                    'action_id'          => actionId,
                    'is_mandatory'       => true,
                    'field_name'         => 'Signature',
                    'field_label'        => 'Signature',
                    'field_category'     => 'image',
                    'description_tooltip'=> '',
                    'is_draggable'       => false,
                    'is_resizable'       => true,
                    'abs_width'          => 115,
                    'abs_height'         => 20,
                    'width'              => '18.790850',
                    'height'             => '2.525253',
                    'x_value'            => '77.249884',
                    'y_value'            => '94.289047',
                    'page_no'            => pageCount,
                    'document_id'        => documentId
                    };
                        
                        Map<String, Object> action = new Map<String, Object>{
                            'action_id'              => actionId,
                                'fields'                 => new List<Object>{ field },
                                    'verify_recipient'       => false,
                                    'recipient_countrycode_iso'=> '',
                                    'action_type'            => 'SIGN',
                                    'cloud_provider_name'    => 'Zoho Sign',
                                    'recipient_email'        => 'gaurav@cloudsciencelabs.com',
                                    'send_completed_document'=> true,
                                    'recipient_phonenumber'  => '',
                                    'is_bulk'                => false,
                                    'signing_order'          => -1,
                                    'cloud_provider_id'      => 10,
                                    'recipient_name'         => 'Gaurav Jha',
                                    'delivery_mode'          => 'EMAIL',
                                    'recipient_countrycode'  => '',
                                    'deleted_fields'         => new List<Object>()
                                    };
                                        
                                        Map<String, Object> body = new Map<String, Object>{
                                            'requests' => new Map<String, Object>{
                                                'actions'         => new List<Object>{ action },
                                                    'deleted_actions' => new List<Object>(),
                                                    'document_fields' => new List<Object>()
                                                    }
                                        };
                                            
                                            String jsonData = JSON.serialize(body);
            String endpoint = 'https://sign.zoho.com/api/v1/requests' + requestId + + '/submit';
            
            HttpRequest req = new HttpRequest();
            req.setEndpoint(endpoint);
            req.setMethod('POST');
            req.setHeader('Content-Type', 'application/json');
            req.setHeader('Authorization', 'Zoho-oauthtoken ' + ACCESS_TOKEN);
            req.setHeader('Accept', 'application/json');
            req.setBody(jsonData);
            req.setTimeout(120000);
            
            HttpResponse res = new Http().send(req);
            System.debug('Submit Response: ' + res.getBody());
            
            if (res.getStatusCode() != 200 && res.getStatusCode() != 201) {
                throw new AuraHandledException('Submit Error: ' + res.getStatusCode() + ' - ' + res.getBody());
            }
            
        } catch (Exception e) {
            throw new AuraHandledException('Submit error: ' + e.getMessage());
        }
    }
    
    public static void updateQuoteWithSignatureDetails(Id quoteId, String requestId) {
        try {
            Quote quoteRecord = new Quote(
                Id = quoteId,
                Status = 'Contract/ Quote Sent',
                Signed_Request_Id__c = requestId
            );
            
            update quoteRecord;
            System.debug('Quote updated with signature details');
            
        } catch (Exception e) {
            System.debug('Error updating quote with signature details: ' + e.getMessage());
        }
    }
    
    private static Blob combineBlobs(List<Blob> blobs) {
        String encodedString = '';
        for (Blob b : blobs) {
            encodedString += EncodingUtil.base64Encode(b);
        }
        return EncodingUtil.base64Decode(encodedString);
    }
}