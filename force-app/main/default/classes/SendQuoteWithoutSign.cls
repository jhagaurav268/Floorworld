public with sharing class SendQuoteWithoutSign {
    @AuraEnabled
    public static void sendQuoteToCustomer(Id quoteId) {
        Quote q = [
            SELECT Id, Name, Quote_Void__c, Email   
            FROM Quote
            WHERE Id = :quoteId
            LIMIT 1
        ];
        
        PageReference pdfPage = Page.QuotePDF;
        pdfPage.getParameters().put('id', q.Id);
        Blob pdfBlob = pdfPage.getContentAsPDF();
                
        Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
        mail.setToAddresses(new String[]{q.Email});
        mail.setSubject('Your Quote from Floorworld');
        mail.setPlainTextBody('Dear Customer,\n\nPlease find attached your finalized quote for review.\n\nBest Regards,\nFloorworld Team');
        
        Messaging.EmailFileAttachment attach = new Messaging.EmailFileAttachment();
        attach.setFileName('Quote_' + q.Name + '.pdf');
        attach.setBody(pdfBlob);
        mail.setFileAttachments(new Messaging.EmailFileAttachment[]{attach});
        
        Messaging.sendEmail(new Messaging.SingleEmailMessage[]{mail});

        q.Quote_Void__c = true;
        update q;
    }
}