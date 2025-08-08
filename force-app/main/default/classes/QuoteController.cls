public class QuoteController {    
    private static List<Id> getNextApproverIds(Quote quoteRecord) {
        List<Id> approverIds = new List<Id>();
        
        String approverRoleName = 'Sales Manager'; 
        List<User> approvers = [
            SELECT Id 
            FROM User 
            WHERE UserRole.Name = :approverRoleName 
            AND IsActive = true
        ];
        
        for (User approver : approvers) {
            approverIds.add(approver.Id);
        }
        
        return approverIds;
    }
    
    @AuraEnabled(cacheable=true)
    public static List<PricebookEntry> getProducts() {
        Pricebook2 pb = [SELECT Id FROM Pricebook2 WHERE Name = 'Floor World Price Book' AND IsActive = true LIMIT 1];
        
        if (pb == null) {
            return new List<PricebookEntry>();
        }
        
        return [
            SELECT Product2.Name, Product2.ProductCode, UnitPrice, Product2.Description, Product2.Family 
            FROM PricebookEntry 
            WHERE Pricebook2Id = :pb.Id 
            AND Product2.Variant__c = false 
            AND IsActive = true
            ORDER BY Product2.Name ASC
        ];
    }
    
    @AuraEnabled(cacheable=true)
    public static String getCurrencyIsoCode(String recordId) {
        System.debug('recordId ==> '+ recordId);
        return [SELECT Opportunity.CurrencyIsoCode 
                FROM Quote 
                WHERE Id = :recordId].Opportunity.CurrencyIsoCode;
    }
    
    @AuraEnabled
    public static Boolean getPendingApprovalStatus(Id quoteId) {
        List<ProcessInstance> pendingApprovals = [
            SELECT Id 
            FROM ProcessInstance 
            WHERE TargetObjectId = :quoteId 
            AND Status = 'Pending'
            LIMIT 1
        ];
        
        return !pendingApprovals.isEmpty();
    }
    
    /*@AuraEnabled
public static List<ProcessInstance> getPendingApprovalRequest(Id quoteId) {
List<ProcessInstance> pendingApprovals = [
SELECT Id, CreatedDate, Status,
(SELECT Id, Actor.Name FROM Workitems WHERE ProcessInstance.status='Pending')
FROM ProcessInstance 
WHERE status='Pending' 
];

return pendingApprovals;
}*/
    public class ApprovalRequestWrapper {
        @AuraEnabled public Id processInstanceId;
        @AuraEnabled public Id quoteId;
        @AuraEnabled public String status;
        @AuraEnabled public String createdDate;
        @AuraEnabled public String actorName;
        @AuraEnabled public Decimal customDiscount;
        @AuraEnabled public Decimal overallAmount;
        @AuraEnabled public Decimal grossProfit;
        @AuraEnabled public Decimal grossProfitPer;
        @AuraEnabled public Decimal finalAmount;
        @AuraEnabled public String quoteName;
        @AuraEnabled public String quoteLink;
        @AuraEnabled public String stepName; 
        @AuraEnabled public String stepLink; 
    }
    
    @AuraEnabled(cacheable=true)
    public static List<ApprovalRequestWrapper> getPendingApprovalRequest() {
        
        List<ProcessInstance> processInstances = [
            SELECT Id, CreatedDate, Status, TargetObjectId,
            (SELECT Id, Actor.Name FROM Workitems WHERE ProcessInstance.Status = 'Pending')
            FROM ProcessInstance
            WHERE Status = 'Pending' AND TargetObject.Type = 'Quote'
        ];
        
        Set<Id> quoteIds = new Set<Id>();
        for (ProcessInstance pi : processInstances) {
            if (pi.TargetObjectId != null) {
                quoteIds.add(pi.TargetObjectId);
            }
        }
        
        Map<Id, Quote> quoteMap = new Map<Id, Quote>(
            [SELECT Id, Name, TotalPrice FROM Quote WHERE Id IN :quoteIds]
        );
        
        List<ApprovalRequestWrapper> wrappers = new List<ApprovalRequestWrapper>();
        for (ProcessInstance pi : processInstances) {
            Quote relatedQuote = quoteMap.get(pi.TargetObjectId);
            ApprovalRequestWrapper wrapper = new ApprovalRequestWrapper();
            wrapper.processInstanceId = pi.Id;
            wrapper.quoteId = pi.TargetObjectId;
            wrapper.status = pi.Status;
            wrapper.createdDate = pi.CreatedDate.format();
            //wrapper.customDiscount = relatedQuote != null ? relatedQuote.Custom_Discount__c : null;
            /*wrapper.finalAmount = relatedQuote != null ? relatedQuote.Final_Amount__c : null;
wrapper.grossProfitPer = relatedQuote != null ? relatedQuote.Est_Gross_Profit_Percents__c : null;
wrapper.grossProfit = relatedQuote != null ? relatedQuote.Gross_Profit__c : null;*/
            wrapper.overallAmount = relatedQuote != null ? relatedQuote.TotalPrice : null;
            wrapper.quoteName = relatedQuote != null ? relatedQuote.Name : null;
            wrapper.quoteLink = '/lightning/r/Quote/' + pi.TargetObjectId + '/view';
            
            List<String> actorNames = new List<String>();
            String stepName = 'Approval Request for '+ wrapper.quoteName;
            String stepLink = '';
            for (ProcessInstanceWorkitem workitem : pi.Workitems) {
                if (workitem.Actor != null) {
                    actorNames.add(workitem.Actor.Name);
                }
                if (stepLink == '' && workitem.Id != null) {
                    stepLink = '/lightning/r/ProcessInstanceWorkitem/' + workitem.Id + '/view';
                }
            }
            wrapper.actorName = String.join(actorNames, ', ');
            wrapper.stepName = stepName;
            wrapper.stepLink = stepLink;
            wrappers.add(wrapper);
        }
        
        return wrappers;
    }
    
    @AuraEnabled(cacheable=true)
    public static List<QuoteLineItemDTO> getExistingQuoteLineItems(Id quoteId) {
        List<QuoteLineItemDTO> result = new List<QuoteLineItemDTO>();
        
        List<QuoteLineItem> qlis = [
            SELECT Id, QuoteId, Product2Id, Product2.Name, Description, Quantity, UnitPrice, Product2.Family,
            Location__c, Net_Area_SQM_LM__c, Wastage__c, Rate__c, Quantity_SQM__c,
            Discount, Length_m__c, Width_m__c, Total_Area__c, Unit__c, Date__c, Gross_Amount__c, Tax_Amount__c, Amount__c
            FROM QuoteLineItem
            WHERE QuoteId = :quoteId
        ];
        
        for (QuoteLineItem qli : qlis) {
            QuoteLineItemDTO dto = new QuoteLineItemDTO();
            dto.salesforceId = qli.Id;
            dto.quoteId = qli.QuoteId;
            dto.productName = qli.Product2.Name;
            dto.location = qli.Location__c;
            dto.productId = qli.Product2Id;
            dto.productDescription = qli.Description;
            dto.productUnitPrice = qli.UnitPrice;
            dto.netArea = qli.Net_Area_SQM_LM__c;
            dto.wastage = qli.Wastage__c;
            dto.rate = qli.Rate__c;
            dto.unitPrice = qli.UnitPrice;
            dto.quantity = qli.Quantity;
            dto.quantityArea = qli.Quantity_SQM__c;
            dto.discountPercentage = qli.Discount;
            dto.length = qli.Length_m__c != null ? String.valueOf(qli.Length_m__c) : null;
            dto.width = qli.Width_m__c != null ? String.valueOf(qli.Width_m__c) : null;
            dto.totalArea = qli.Total_Area__c;
            dto.units = qli.Unit__c;
            dto.rowId = qli.Id; 
            dto.price = (qli.UnitPrice != null && qli.Quantity != null) ? qli.UnitPrice * qli.Quantity : null;
            dto.amount = qli.Amount__c;
            dto.taxAmount = qli.Tax_Amount__c;
            dto.grossAmount = qli.Gross_Amount__c;
            dto.productFamily = qli.Product2.Family;
            result.add(dto);
        }
        
        return result;
    }

    
    @AuraEnabled
    public static Boolean upsertQuoteLineItems(Object lineItemsData, Decimal discountPercent) {
        try{
            System.debug('createQuoteLineItems called');
            List<Object> lineItemsObj = (List<Object>) JSON.deserializeUntyped(JSON.serialize(lineItemsData));

            List<QuoteLineItemWrapper> lineItems = new List<QuoteLineItemWrapper>();
            System.debug('lineItemsObj ' + lineItemsObj);
            for (Object item : lineItemsObj) {
                Map<String, Object> itemMap = (Map<String, Object>) item;
                QuoteLineItemWrapper wrapper = new QuoteLineItemWrapper();
                wrapper.quoteLineItemId = (Id) itemMap.get('salesforceId');
                wrapper.quoteId = (Id) itemMap.get('quoteId');
                wrapper.location = (String) itemMap.get('location');
                wrapper.productId = (Id) itemMap.get('productId');
                wrapper.productDescription = (String) itemMap.get('productDescription');
                wrapper.netArea = itemMap.get('netArea') != null ? Decimal.valueOf(String.valueOf(itemMap.get('netArea'))) : null;
                wrapper.wastage = itemMap.get('wastage') != null ? Decimal.valueOf(String.valueOf(itemMap.get('wastage'))) : null;
                wrapper.length = (String) itemMap.get('length');
                wrapper.width = (String) itemMap.get('width');
                wrapper.totalArea = itemMap.get('totalArea') != null ? Decimal.valueOf(String.valueOf(itemMap.get('totalArea'))) : null;
                wrapper.rate = itemMap.get('rate') != null ? Decimal.valueOf(String.valueOf(itemMap.get('rate'))) : null;
                wrapper.amount = itemMap.get('price') != null ? Decimal.valueOf(String.valueOf(itemMap.get('price'))) : null;
                wrapper.taxAmount = itemMap.get('taxAmount') != null ? Decimal.valueOf(String.valueOf(itemMap.get('taxAmount'))) : null;
                wrapper.grossAmount = itemMap.get('grossAmount') != null ? Decimal.valueOf(String.valueOf(itemMap.get('grossAmount'))) : null;
                wrapper.productUnitPrice = itemMap.get('productUnitPrice') != null ? Decimal.valueOf(String.valueOf(itemMap.get('productUnitPrice'))) : null;
                wrapper.quantity = itemMap.get('quantity') != null ? Decimal.valueOf(String.valueOf(itemMap.get('quantity'))) : null;
                wrapper.quantityArea = itemMap.get('quantityArea') != null ? Decimal.valueOf(String.valueOf(itemMap.get('quantityArea'))) : null;
                wrapper.discountPercentage = itemMap.get('discountPercentage') != null ? Decimal.valueOf(String.valueOf(itemMap.get('discountPercentage'))) : null;
                wrapper.discountId = (String) itemMap.get('discountId');
                wrapper.rowId = (String) itemMap.get('rowId');
                wrapper.units = (String) itemMap.get('units');
                System.debug('units ' + wrapper.units);
                lineItems.add(wrapper);
            }
            system.debug('After for');
            List<QuoteLineItem> quoteLineItemsToInsert = new List<QuoteLineItem>();
            Map<String, QuoteLineItem> externalIdToSalesforceIdMap = new Map<String, QuoteLineItem>();
            Map<String, String> discountIdToRowIdMap = new Map<String, String>();
            Id quoteId;
            Pricebook2 floorWorldPB = [SELECT Id FROM Pricebook2 WHERE Name = 'Floor World Price Book' AND IsActive = true LIMIT 1];
            system.debug('floorWorldPB ' + floorWorldPB);

            Set<Id> productIds = new Set<Id>();
            for (QuoteLineItemWrapper item : lineItems) {
                if (item.productId != null) {
                    productIds.add(item.productId);
                }
            }
            
            Map<Id, Id> productToPBEMap = new Map<Id, Id>();
            for (PricebookEntry pbe : [
                SELECT Id, Product2Id 
                FROM PricebookEntry 
                WHERE Product2Id IN :productIds 
                AND Pricebook2Id = :floorWorldPB.Id 
                AND IsActive = true
            ]) {
                productToPBEMap.put(pbe.Product2Id, pbe.Id);
            }
            
            for (QuoteLineItemWrapper item : lineItems) {
                QuoteLineItem qli = new QuoteLineItem();
                qli.Id = item.quoteLineItemId;
                if(item.quoteLineItemId == null){
                    qli.QuoteId = item.quoteId;
                    qli.Product2Id = item.productId;
                    qli.PricebookEntryId = productToPBEMap.get(item.productId);
                }
                quoteId = item.quoteId;
                qli.Location__c = item.location;
                qli.Net_Area_SQM_LM__c = item.netArea;
                qli.Date__c = Date.today();
                Decimal clientWastage = item.wastage != null ? item.wastage : 0;
                qli.Wastage__c = clientWastage;
                
                qli.Quantity = (item.quantity != null) ? Integer.valueOf(item.quantity) : null;
                qli.UnitPrice = item.productUnitPrice;
                qli.Rate__c = item.rate;
                qli.Amount__c = item.amount;
                qli.Tax_Amount__c = item.taxAmount;
                qli.Gross_Amount__c = item.grossAmount;
                qli.Quantity_SQM__c = item.quantityArea;
                qli.Discount = (item.discountPercentage != null) ? item.discountPercentage : null; 
                qli.Description = item.productDescription;
                qli.Length_m__c = (item.length != null && item.length != '') ? Decimal.valueOf(item.length) : null; 
                qli.Width_m__c = (item.width != null && item.width != '') ? Decimal.valueOf(item.width) : null;
                qli.Total_Area__c = (item.totalArea != null) ? item.totalArea : null;
                qli.Unit__c = item.units;
                System.debug('qli.Unit__c ' + qli.Unit__c);
                if(item.rowId != null){
                    externalIdToSalesforceIdMap.put(item.rowId, qli);
                }
                if(item.discountId != null){
                    discountIdToRowIdMap.put(item.discountId, item.rowId);
                }
                System.debug('qli'+qli);
                quoteLineItemsToInsert.add(qli);
            }
            
            if (!quoteLineItemsToInsert.isEmpty()) {
                Database.upsert(quoteLineItemsToInsert,true);
                return true;
                /*ist<QuoteLineItem> quoteLineItemsToUpdate = new List<QuoteLineItem>();
                for(String discountIds : discountIdToRowIdMap.keyset()){
                    if(discountIdToRowIdMap.get(discountIds) != null){
                        QuoteLineItem qli = externalIdToSalesforceIdMap.get(discountIdToRowIdMap.get(discountIds));
                        QuoteLineItem discountQli =  externalIdToSalesforceIdMap.get(discountIds);
                        if(qli != null){
                            quoteLineItemsToUpdate.add(qli);
                        }
                    }
                }
                if (!quoteLineItemsToUpdate.isEmpty()) {
                    update quoteLineItemsToUpdate;
                }*/
            }
            return false;

            /*if(discountPercent != null && discountPercent > 0){
                Quote quot = new Quote();
                quot.Id = quoteId;
                update quot;
            }else{
                calculateQuoteDiscount([SELECT Id, QuoteId, TotalPrice, Discount from QuoteLineItem Where QuoteId =: quoteId]);
            }*/
        }catch (Exception ex) {
            System.debug('Error in createQuoteLineItems: ' + ex.getMessage() + ' - ' +  ex.getLineNumber());
            throw new AuraHandledException('Error while creating Quote Line Items: ' + ex.getMessage());
        }
    }
    
    public class QuoteLineItemWrapper {
        public Id quoteLineItemId;
        public Id quoteId;
        public String location;
        public Id productId;
        public String productDescription;
        public Decimal netArea;
        public Decimal wastage;
        public String length;
        public String width;
        public Decimal totalArea;
        public Decimal rate;
        public Decimal amount;
        public Decimal taxAmount;
        public Decimal grossAmount;
        public Decimal productUnitPrice;
        public Decimal quantity;
        public Decimal quantityArea;
        public Decimal discountPercentage;
        public String discountId;
        public String rowId;
        public String units;
    }
    
    public static void calculateQuoteDiscount(List<QuoteLineItem> quoteLineItems) {
        
        Map<Id, Decimal> totalAmountsByQuote = new Map<Id, Decimal>();
        Map<Id, Decimal> weightedDiscountsByQuote = new Map<Id, Decimal>();
        
        for (QuoteLineItem qli : quoteLineItems) {
            if (qli.QuoteId != null) {
                
                if (!totalAmountsByQuote.containsKey(qli.QuoteId)) {
                    totalAmountsByQuote.put(qli.QuoteId, 0);
                    weightedDiscountsByQuote.put(qli.QuoteId, 0);
                }
                
                totalAmountsByQuote.put(qli.QuoteId, totalAmountsByQuote.get(qli.QuoteId) + qli.TotalPrice);
                
                if (qli.Discount != null && qli.Discount > 0) {
                    weightedDiscountsByQuote.put(qli.QuoteId, 
                                                 weightedDiscountsByQuote.get(qli.QuoteId) + (qli.Discount * qli.TotalPrice));
                }
            }
        }
        
        Map<Id, Decimal> quoteDiscounts = new Map<Id, Decimal>();
        for (Id quoteId : totalAmountsByQuote.keySet()) {
            Decimal totalAmount = totalAmountsByQuote.get(quoteId);
            Decimal weightedDiscount = weightedDiscountsByQuote.get(quoteId);
            
            if (totalAmount > 0) {
                quoteDiscounts.put(quoteId, totalAmount > 0 ? (weightedDiscount / totalAmount).setScale(2, RoundingMode.HALF_UP) : 0);
            } else {
                quoteDiscounts.put(quoteId, 0);
            }
        }
        
        List<Quote> quotesToUpdate = new List<Quote>();
        for (Id quoteId : quoteDiscounts.keySet()) {
            quotesToUpdate.add(new Quote(
                Id = quoteId
                //Custom_Discount__c = quoteDiscounts.get(quoteId) 
            ));
        }
        
        if (!quotesToUpdate.isEmpty()) {
            update quotesToUpdate;
        }
    }
    
    public static void updateCPOnQuote(List<QuoteLineItem> qutLine){
        Set<Id> quotesId = new Set<Id>();
        
        for (QuoteLineItem li : qutLine) {
            if(li.QuoteId != null){
                quotesId.add(li.QuoteId);
            }
        }
        
        Map<Id, Decimal> quoteTotalsMap = new Map<Id, Decimal>();
        
        for (QuoteLineItem qli : [SELECT Id, QuoteId,Quote.Discount, Quantity FROM QuoteLineItem WHERE QuoteId IN :quotesId]) {
            Decimal total = 0;//qli.Cost_Prize__c;
            
            if (!quoteTotalsMap.containsKey(qli.QuoteId)) {
                quoteTotalsMap.put(qli.QuoteId, 0);
            }
            
            quoteTotalsMap.put(qli.QuoteId, quoteTotalsMap.get(qli.QuoteId) + total);
        }
        
        
        List<Quote> quotesToUpdate = new List<Quote>();
        
        for(Id qutId : quotesId){
            if(quoteTotalsMap.containsKey(qutId)){
                quotesToUpdate.add(new Quote(
                    Id = qutId
                    //Cost_Prize__c = quoteTotalsMap.get(qutId)
                ));
            }
        }
        
        if (!quotesToUpdate.isEmpty()) {
            update quotesToUpdate;
        }
        
    }
    
    @AuraEnabled(cacheable=true)
    public static List<PricebookEntry> searchProductItems(String searchKey) {
        Pricebook2 pb = [SELECT Id FROM Pricebook2 WHERE Name = 'Floor World Price Book' AND IsActive = true LIMIT 1];
        
        if (pb == null) {
            return new List<PricebookEntry>();
        }
        
        String query = '%' + searchKey + '%';
        
        return [SELECT Product2.Name, Product2.ProductCode, UnitPrice, Product2.Description, Product2.Family, Product2.Primary_Sale_Unit__c, Product2.Width_m__c
                //Product2.Area_Per_Box__c, Product2.Width__c, Cost_Prize__c
                FROM PricebookEntry 
                WHERE Pricebook2.Id =: pb.Id AND Name LIKE :query LIMIT 10];
    }
    
    public class QuoteLineItemDTO {
        @AuraEnabled
        public String salesforceId { get; set; }
        @AuraEnabled
        public String quoteId { get; set; }
        @AuraEnabled
        public String productName { get; set; }
        @AuraEnabled
        public String productFamily { get; set; }
        @AuraEnabled
        public String location { get; set; }
        @AuraEnabled
        public String productId { get; set; }
        @AuraEnabled
        public Decimal productUnitPrice { get; set; }
        @AuraEnabled
        public Decimal netArea { get; set; }
        @AuraEnabled
        public Decimal wastage { get; set; }
        @AuraEnabled
        public Decimal rate { get; set; }
        @AuraEnabled
        public String productDescription { get; set; }
        @AuraEnabled
        public String length { get; set; }
        @AuraEnabled
        public String width { get; set; }
        @AuraEnabled
        public Decimal totalArea { get; set; }
        @AuraEnabled
        public Decimal quantity { get; set; }
        @AuraEnabled
        public Decimal quantityArea { get; set; }
        @AuraEnabled
        public Decimal discountPercentage { get; set; }
        @AuraEnabled
        public String discountId { get; set; }
        @AuraEnabled
        public String rowId { get; set; }
        @AuraEnabled
        public String units { get; set; }
        @AuraEnabled
        public Decimal amount { get; set; }
        @AuraEnabled
        public Decimal taxAmount { get; set; }
        @AuraEnabled
        public Decimal grossAmount { get; set; }
        @AuraEnabled
        public Decimal price { get; set; }
        @AuraEnabled
        public Decimal unitPrice { get; set; }
        @AuraEnabled
        public Decimal costPrice { get; set; }
        @AuraEnabled
        public String type { get; set; }
        
    }
    
}