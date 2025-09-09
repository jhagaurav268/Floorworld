@RestResource(urlMapping='/zohoresponse/*')
global class ZohoSignWebhookController {
    
    private static final Map<String, Map<String, String>> OBJECT_CONFIGS = new Map<String, Map<String, String>>{
        'Quote' => new Map<String, String>{
            'numberField' => 'QuoteNumber',
            'signedField' => 'Is_Quote_Signed__c',
            'completedStatus' => 'Quote Signed',
            'declinedStatus' => 'Quote Declined',
            'sentStatus' => 'Contract/ Quote Sent'
        },
        'Order' => new Map<String, String>{
            'numberField' => 'OrderNumber',
            'signedField' => 'Is_Order_Signed__c',
            'completedStatus' => 'Order Signed',
            'declinedStatus' => 'Order Declined',
            'sentStatus' => 'Order Sent'
        }
    };
    
    @HttpPost
    webservice static void processWebhook() {
        RestRequest req = RestContext.request;
        String responseString = req.requestBody.toString();
        
        Map<String, Object> dataMap = (Map<String, Object>) JSON.deserializeUntyped(responseString);
        
        String requestId;
        String requestStatus;
        String declineReason;
        
        if (dataMap.containsKey('requests')) {
            Map<String, Object> requestsMap = (Map<String, Object>) dataMap.get('requests');
            requestId = (String) requestsMap.get('request_id');
            requestStatus = (String) requestsMap.get('request_status');
        }
        
        if (dataMap.containsKey('notifications')) {
            Map<String, Object> notificationsMap = (Map<String, Object>) dataMap.get('notifications');
            if (notificationsMap.containsKey('reason')) {
                declineReason = (String) notificationsMap.get('reason');
            }
        }
        
        System.debug('Zoho request_id: ' + requestId);
        System.debug('Zoho request_status: ' + requestStatus);
        System.debug('Zoho reason: ' + declineReason);
        
        if (String.isNotBlank(requestId)) {
            sObject recordToUpdate = findRecordByRequestId(requestId);
            
            if (recordToUpdate != null) {
                updateRecord(recordToUpdate, requestStatus, declineReason, requestId);
            } else {
                System.debug('No matching Quote or Order found for request_id ' + requestId);
            }
        }
    }
    
    private static sObject findRecordByRequestId(String requestId) {
        List<sObject> quotes = Database.query(
            'SELECT Id, Signed_Request_Id__c, Status, Decline_Reason__c, Name, QuoteNumber, Is_Quote_Signed__c ' +
            'FROM Quote ' +
            'WHERE Signed_Request_Id__c = :requestId ' +
            'LIMIT 1'
        );
        
        if (!quotes.isEmpty()) {
            return quotes[0];
        }
        
        List<sObject> orders = Database.query(
            'SELECT Id, Signed_Request_Id__c, Status, Decline_Reason__c, Name, OrderNumber, Is_Order_Signed__c ' +
            'FROM Order ' +
            'WHERE Signed_Request_Id__c = :requestId ' +
            'LIMIT 1'
        );
        
        if (!orders.isEmpty()) {
            return orders[0];
        }
        
        return null;
    }
    
    private static void updateRecord(sObject record, String requestStatus, String declineReason, String requestId) {
        String objectType = String.valueOf(record.getSObjectType());
        Map<String, String> config = OBJECT_CONFIGS.get(objectType);
        
        if (config == null) {
            System.debug('No configuration found for object type: ' + objectType);
            return;
        }
        
        String documentNumber = (String) record.get(config.get('numberField'));
        
        if (requestStatus == 'completed') {
            record.put('Status', config.get('completedStatus'));
            record.put('Decline_Reason__c', '');
            record.put(config.get('signedField'), true);
            
            downloadAndAttachSignedDocument((Id) record.get('Id'), requestId, documentNumber, objectType);
            
        } else if (requestStatus == 'declined') {
            record.put('Status', config.get('declinedStatus'));
        } else {
            record.put('Status', config.get('sentStatus'));
        }
        
        if (String.isNotBlank(declineReason)) {
            record.put('Decline_Reason__c', declineReason);
        }
        
        try {
            update record;
            System.debug(objectType + ' updated: ' + record.get('Id') + ' | Status: ' + record.get('Status') + ' | Reason: ' + record.get('Decline_Reason__c'));
        } catch (Exception e) {
            System.debug('Error updating ' + objectType + ': ' + e.getMessage());
        }
    }
    
    private static void downloadAndAttachSignedDocument(Id recordId, String requestId, String documentNumber, String recordType) {
        try {
            HttpRequest req = new HttpRequest();
            req.setEndpoint('callout:Zoho/api/v1/requests/' + requestId + '/pdf');
            req.setMethod('GET');
            req.setTimeout(60000); 
            
            Http http = new Http();
            HttpResponse response = http.send(req);
            
            if (response.getStatusCode() == 200) {
                Blob pdfBlob = response.getBodyAsBlob();
                
                ContentVersion contentVersion = new ContentVersion();
                contentVersion.Title = 'Signed ' + recordType + ' ' + (String.isNotBlank(documentNumber) ? documentNumber : requestId);
                contentVersion.PathOnClient = 'Signed_' + recordType + '_' + (String.isNotBlank(documentNumber) ? documentNumber : requestId) + '.pdf';
                contentVersion.VersionData = pdfBlob;
                contentVersion.ContentLocation = 'S';
                contentVersion.Description = 'Signed document from Zoho Sign - Request ID: ' + requestId;
                
                insert contentVersion;
                
                ContentVersion insertedCV = [SELECT ContentDocumentId FROM ContentVersion WHERE Id = :contentVersion.Id LIMIT 1];
                
                ContentDocumentLink contentDocumentLink = new ContentDocumentLink();
                contentDocumentLink.ContentDocumentId = insertedCV.ContentDocumentId;
                contentDocumentLink.LinkedEntityId = recordId;
                contentDocumentLink.ShareType = 'V'; 
                contentDocumentLink.Visibility = 'AllUsers'; 
                
                insert contentDocumentLink;
                
                System.debug('Successfully attached signed document to ' + recordType + ': ' + recordId + ' | ContentVersion Id: ' + contentVersion.Id + ' | ContentDocument Id: ' + insertedCV.ContentDocumentId);
                
            } else {
                System.debug('Error downloading PDF. Status Code: ' + response.getStatusCode() + ' | Status: ' + response.getStatus() + ' | Body: ' + response.getBody());
            }
            
        } catch (Exception e) {
            System.debug('Exception occurred while downloading/attaching PDF: ' + e.getMessage());
            System.debug('Stack Trace: ' + e.getStackTraceString());
        }
    }
}