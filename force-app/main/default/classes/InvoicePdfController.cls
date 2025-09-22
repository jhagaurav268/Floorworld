public with sharing class InvoicePdfController {
    public Order order { get; set; }
    public List<OrderItem> orderProducts { get; set; }
    public Proforma_Invoice__c proformaInvoice { get; set; }
    public String amountInWords { get; set; }

    public InvoicePdfController() {
        String invoiceId = ApexPages.currentPage().getParameters().get('id');
        
        if (String.isNotBlank(invoiceId)) {
            loadInvoiceData(invoiceId);
        }
    }
    
    public InvoicePdfController(ApexPages.StandardController stdController) {
        String invoiceId = stdController.getId();
        if (String.isNotBlank(invoiceId)) {
            loadInvoiceData(invoiceId);
        }
    }

    private void loadInvoiceData(String invoiceId) {
        try {
            proformaInvoice = [SELECT Id, OwnerId, IsDeleted, Name, CurrencyIsoCode,
                               Order__c, Proforma_Invoice__c, Proforma_Invoice_Amount__c
                               FROM Proforma_Invoice__c WHERE Id =: invoiceId LIMIT 1];

            order = [SELECT Id, Name, OrderNumber, CreatedDate, Opportunity.Name, Sales_Rep__r.Name, Discounted_Amount__c,
                     Total_Price__c, VAT__c, Tax_Amount__c, Grand_Total__c, Account.Phone, Branch__r.Name, Payment_Terms__c,
                     Account.ShippingAddress, Account.ShippingStreet, Account.ShippingCity, Discount__c, Good_Available__c,
                     Supply_Type__c, Shipping_Method__c, Account.ShippingState, Quote.Email, Branch__r.Branch_Phone__c, Balance_Due__c,
                     Owner.Name, Account.BillingStreet, Account.BillingCity, Account.ShippingCountry, Account.ShippingPostalCode,
                     Account.Name, Account.AccountNumber, Account.BillingState, Account.BillingPostalCode, Account.BillingCountry,
                     Contact__r.Name, Contact__r.Phone, Contact__r.MobilePhone, Contact__r.Email, Branch__r.Branch_Address__c
                     FROM Order 
                     WHERE Id = :proformaInvoice.Order__c 
                     LIMIT 1];
            
            orderProducts = [SELECT Id, Product2.Name, Product2.ProductCode, Gross_Amount__c, Quantity_SQM__c,
                              Description, Quantity, UnitPrice, TotalPrice, Discounted_Price__c,
                              Location__c, Product2.Box_s_Per_Pallet__c, Product2.Weight_Per_Box_PCS_Kg__c,
                              Net_Area_Sqm_Lm__c, Unit__c, Discount__c, Product2.Primary_Consumption_Unit__c
                              FROM OrderItem 
                              WHERE OrderId = :order.Id
                             AND (NOT (Product2.Name LIKE '%Discount%'
                                   OR Product2.Name LIKE '%discount%'
                                   OR Description LIKE '%discount%'
                                   OR Description LIKE '%Discount%'))
                              Order By OrderItemNumber ASC];
            
            amountInWords = CurrencyToWords.amountToWords(order.Grand_Total__c, order.CurrencyIsoCode);
        } catch (Exception e) {
            ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.ERROR, 
                                                       'Error loading invoice data: ' + e.getMessage()));
        }
    }
    
    public Decimal getVATPercentage() {
        return 5.0;
    }
    
    public Decimal getTotalSQM() {
        Decimal totalSQM = 0;
        if (orderProducts != null && !orderProducts.isEmpty()) {
            for (OrderItem item : orderProducts) {
                if (item.Unit__c != null && item.Unit__c.contains('SqM') && item.Net_Area_Sqm_Lm__c != null) {
                    totalSQM += item.Net_Area_Sqm_Lm__c;
                }
            }
        }
        return totalSQM;
    }
    
    public Decimal getTotalLM() {
        Decimal totalLM = 0;
        if (orderProducts != null && !orderProducts.isEmpty()) {
            for (OrderItem item : orderProducts) {
                if (item.Unit__c != null && item.Unit__c.equalsIgnoreCase('MTR') && item.Net_Area_Sqm_Lm__c != null) {
                    totalLM += item.Net_Area_Sqm_Lm__c;
                }
            }
        }
        return totalLM;
    }
    
    public Decimal getTotalBox() {
        Decimal totalBox = 0;
        if (orderProducts != null && !orderProducts.isEmpty()) {
            for (OrderItem item : orderProducts) {
                if (item.Product2.Primary_Consumption_Unit__c != null && 
                    item.Product2.Primary_Consumption_Unit__c.equalsIgnoreCase('boxes') && 
                    item.Quantity != null) {
                    totalBox += item.Quantity;
                }
            }
        }
        return totalBox;
    }
    
    public Decimal getTotalPCS() {
        Decimal totalPCS = 0;
        if (orderProducts != null && !orderProducts.isEmpty()) {
            for (OrderItem item : orderProducts) {
                if ((item.Product2.Primary_Consumption_Unit__c == null || 
                     !item.Product2.Primary_Consumption_Unit__c.equalsIgnoreCase('boxes')) && 
                    item.Quantity != null) {
                    totalPCS += item.Quantity;
                }
            }
        }
        return totalPCS;
    }
    
    public Decimal getTotalPallets() {
        Decimal totalPallets = 0;
        if (orderProducts != null && !orderProducts.isEmpty()) {
            for (OrderItem item : orderProducts) {
                if (item.Product2.Box_s_Per_Pallet__c != null) {
                    totalPallets += item.Product2.Box_s_Per_Pallet__c;
                }
            }
        }
        return totalPallets;
    }
    
    public Decimal getTotalWeight() {
        Decimal totalWeight = 0;
        if (orderProducts != null && !orderProducts.isEmpty()) {
            for (OrderItem item : orderProducts) {
                if (item.Quantity != null && item.Product2.Weight_Per_Box_PCS_Kg__c != null) {
                    totalWeight += item.Quantity * item.Product2.Weight_Per_Box_PCS_Kg__c;
                }
            }
        }
        return totalWeight;
    }
}