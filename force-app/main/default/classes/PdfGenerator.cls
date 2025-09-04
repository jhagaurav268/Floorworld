public with sharing class PdfGenerator {
    public class Request {
        @InvocableVariable(required=true)
        public Id invoiceId;
    }
    
    @InvocableMethod(label='Generate PDF from VF Page')
    public static void generatePdf(List<Request> requests) {
        for (Request req : requests) {
            if (req.invoiceId == null) continue;
            PageReference pdfPage = Page.InvoicePdf;
            pdfPage.getParameters().put('id', String.valueOf(req.invoiceId));
            System.debug(req.invoiceId);
            Proforma_Invoice__c proformaInvoice = [SELECT Id, OwnerId, IsDeleted, Name, CurrencyIsoCode,
                                                   Order__c, Proforma_Invoice__c, Proforma_Invoice_Amount__c
                                                   FROM Proforma_Invoice__c WHERE Id =: req.invoiceId LIMIT 1];
            System.debug(proformaInvoice);
            
            Blob pdfBlob = pdfPage.getContentAsPDF();
            
            ContentVersion contentVersion = new ContentVersion();
            contentVersion.Title = proformaInvoice.Name + '_' + proformaInvoice.Proforma_Invoice__c;
            contentVersion.PathOnClient = proformaInvoice.Name + '_' + proformaInvoice.Proforma_Invoice__c + '.pdf';
            contentVersion.VersionData = pdfBlob;
            contentVersion.ContentLocation = 'S';
            contentVersion.Description = 'Proforma Invoice Created - ' + proformaInvoice.Name + '_' + proformaInvoice.Proforma_Invoice__c;
            
            insert contentVersion;
            
            ContentVersion insertedCV = [SELECT ContentDocumentId FROM ContentVersion WHERE Id = :contentVersion.Id LIMIT 1];
            
            ContentDocumentLink contentDocumentLink = new ContentDocumentLink();
            contentDocumentLink.ContentDocumentId = insertedCV.ContentDocumentId;
            contentDocumentLink.LinkedEntityId = req.invoiceId;
            contentDocumentLink.ShareType = 'V'; 
            contentDocumentLink.Visibility = 'AllUsers'; 
            
            insert contentDocumentLink;
            
        }
    }
}