public with sharing class OrderSignController {
    
    private static final String ORDER_STATUS_SENT = 'Order Sent';
    
    @AuraEnabled
    public static String handleOrderSign(Id orderId) {
        try {
            if (orderId == null) {
                throw new AuraHandledException('Order ID cannot be null');
            }
            System.debug('orderId ' + orderId);
            Order o = [
                SELECT Id, Account.Name, EffectiveDate, Quote.Email
                FROM Order
                WHERE Id = :orderId
                LIMIT 1
            ];
            
            if (String.isBlank(o.Quote.Email)) {
                throw new AuraHandledException('No recipient email found for this Order');
            }
            
            ZohoSignService.SignatureRequest signatureRequest = new ZohoSignService.SignatureRequest(
                orderId,
                o.Account.Name,
                o.Quote.Email,
                'Order Signature Request',
                'Status',
                ORDER_STATUS_SENT,
                'Signed_Request_Id__c'
            );
            
            return ZohoSignService.processDocumentForSignature(signatureRequest);
            
        } catch (Exception e) {
            System.debug('Error in handleOrderSign: ' + e.getMessage());
            throw new AuraHandledException('Failed to process order signature: ' + e.getMessage());
        }
    }
}