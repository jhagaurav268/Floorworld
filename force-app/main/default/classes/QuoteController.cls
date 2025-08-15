public class QuoteController {    
    
    @AuraEnabled(cacheable=true)
    public static List<QuoteLineItemDTO> getExistingQuoteLineItems(Id quoteId) {
        List<QuoteLineItemDTO> result = new List<QuoteLineItemDTO>();
        
        Quote quote = [
            SELECT Id, Discount__c, Discounted_Amount__c 
            FROM Quote 
            WHERE Id = :quoteId 
            LIMIT 1
        ];
        
        List<QuoteLineItem> qlis = [
            SELECT Id, QuoteId, Product2Id, Product2.Name, Description, Quantity, UnitPrice, Product2.Family,
            Location__c, Net_Area_SQM_LM__c, Wastage__c, Rate__c, Quantity_SQM__c,
            Discount, Length_m__c, Width_m__c, Total_Area__c, Unit__c, Date__c, Gross_Amount__c, Tax_Amount__c, Amount__c,
            Row_Number__c
            FROM QuoteLineItem
            WHERE QuoteId = :quoteId
            ORDER BY Row_Number__c ASC NULLS LAST, CreatedDate ASC
        ];
        
        for (QuoteLineItem qli : qlis) {
            QuoteLineItemDTO dto = new QuoteLineItemDTO();
            dto.salesforceId = qli.Id;
            dto.quoteId = qli.QuoteId;
            dto.productName = qli.Product2 != null ? qli.Product2.Name : '';
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
            dto.productFamily = qli.Product2 != null ? qli.Product2.Family : '';
            dto.rowNumber = qli.Row_Number__c != null ? Integer.valueOf(qli.Row_Number__c) : null;
            
            List<String> individualDiscountProducts = new List<String>{'5% Discount', '10% Discount', '15% Discount', '20% Discount'};
            dto.isIndividualDiscount = individualDiscountProducts.contains(dto.productName);
            
            result.add(dto);
        }
        
        if (quote.Discount__c != null && quote.Discount__c > 0) {
            Decimal totalRate = 0;
            Decimal totalUnitPrice = 0;
            Decimal totalAmount = 0;
            Decimal totalTaxAmount = 0;
            Decimal totalGrossAmount = 0;
            
            for (QuoteLineItemDTO item : result) {
                if (item.rate != null) totalRate += item.rate;
                if (item.unitPrice != null) totalUnitPrice += item.unitPrice;
                if (item.amount != null) totalAmount += item.amount;
                if (item.taxAmount != null) totalTaxAmount += item.taxAmount;
                if (item.grossAmount != null) totalGrossAmount += item.grossAmount;
            }
            
            Decimal discountRate = (totalRate * quote.Discount__c) / 100;
            Decimal discountUnitPrice = (totalUnitPrice * quote.Discount__c) / 100;
            Decimal discountAmountOnly = (totalAmount * quote.Discount__c) / 100;
            Decimal discountTaxAmount = (totalTaxAmount * quote.Discount__c) / 100;
            Decimal discountGrossAmount = (totalGrossAmount * quote.Discount__c) / 100;
            
            QuoteLineItemDTO discountDto = new QuoteLineItemDTO();
            discountDto.salesforceId = null;
            discountDto.quoteId = quoteId;
            discountDto.productName = 'Discount (' + quote.Discount__c + '%)';
            discountDto.location = 'Discount';
            discountDto.productDescription = quote.Discount__c + '% discount on total amount';
            discountDto.quantity = 1;
            discountDto.rate = -discountRate;
            discountDto.unitPrice = -discountUnitPrice;
            discountDto.amount = -discountAmountOnly;
            discountDto.taxAmount = -discountTaxAmount;
            discountDto.grossAmount = -discountGrossAmount;
            discountDto.productFamily = 'Discount';
            discountDto.family = 'Discount';
            discountDto.rowNumber = 9999; // Always at the end
            result.add(discountDto);
        }
        
        return result;
    }
    
    @AuraEnabled
    public static Map<String, String> upsertQuoteLineItems(Object lineItemsData, Decimal discountPercent, Decimal discountAmount, List<String> deletedRowIds) {
        try{
            System.debug('createQuoteLineItems called');
            if (deletedRowIds != null && !deletedRowIds.isEmpty()) {
                List<QuoteLineItem> itemsToDelete = [
                    SELECT Id FROM QuoteLineItem 
                    WHERE Id IN :deletedRowIds
                ];
                delete itemsToDelete;
            }

            List<Object> lineItemsObj = (List<Object>) JSON.deserializeUntyped(JSON.serialize(lineItemsData));
            
            List<QuoteLineItemWrapper> lineItems = new List<QuoteLineItemWrapper>();
            System.debug('lineItemsObj ' + lineItemsObj);
            
            for (Object item : lineItemsObj) {
                Map<String, Object> itemMap = (Map<String, Object>) item;
                QuoteLineItemWrapper wrapper = new QuoteLineItemWrapper();
                wrapper.quoteLineItemId = (Id) itemMap.get('salesforceId');
                wrapper.quoteId = (Id) itemMap.get('quoteId');
                wrapper.location = (String) itemMap.get('location');
                Object productIdObj = itemMap.get('productId');
                if (productIdObj != null && String.valueOf(productIdObj) != '' && String.valueOf(productIdObj) != 'null') {
                    wrapper.productId = (Id) productIdObj;
                } else {
                    wrapper.productId = null;
                }
                
                wrapper.productDescription = (String) itemMap.get('productDescription');
                wrapper.netArea = itemMap.get('netArea') != null ? Decimal.valueOf(String.valueOf(itemMap.get('netArea'))) : null;
                wrapper.wastage = itemMap.get('wastage') != null ? Decimal.valueOf(String.valueOf(itemMap.get('wastage'))) : null;
                wrapper.length = (String) itemMap.get('length');
                wrapper.width = String.valueOf(itemMap.get('width'));
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
                wrapper.itemType = (String) itemMap.get('type');
                wrapper.isIndividualDiscount = (Boolean) itemMap.get('isIndividualDiscount');
                wrapper.rowNumber = itemMap.get('rowNumber') != null ? Integer.valueOf(String.valueOf(itemMap.get('rowNumber'))) : null;
                
                System.debug('units ' + wrapper.units);
                System.debug('rowId from frontend: ' + wrapper.rowId); // Debug line
                lineItems.add(wrapper);
            }
            
            system.debug('After for');
            List<QuoteLineItem> quoteLineItemsToUpsert = new List<QuoteLineItem>();
            Map<String, QuoteLineItem> externalIdToSalesforceIdMap = new Map<String, QuoteLineItem>();
            Map<String, String> discountIdToRowIdMap = new Map<String, String>();
            // Move this declaration up and initialize here
            Map<String, QuoteLineItem> rowIdToQliMap = new Map<String, QuoteLineItem>();
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
            
            List<QuoteLineItemWrapper> itemsToProcess = new List<QuoteLineItemWrapper>();
            for (QuoteLineItemWrapper item : lineItems) {
                if (!(item.location == 'Discount' && item.itemType == 'Discount')) {
                    itemsToProcess.add(item);
                }
            }
            
            for (QuoteLineItemWrapper item : itemsToProcess) {
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
                qli.Row_Number__c = item.rowNumber;
                
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
                System.debug('Item Type: ' + item.itemType);
                System.debug('Is Individual Discount: ' + item.isIndividualDiscount);
                
                // FIX: Add to both maps
                if(item.rowId != null){
                    externalIdToSalesforceIdMap.put(item.rowId, qli);
                    rowIdToQliMap.put(item.rowId, qli); // This was missing!
                    System.debug('Added to rowIdToQliMap: ' + item.rowId); // Debug line
                }
                if(item.discountId != null){
                    discountIdToRowIdMap.put(item.discountId, item.rowId);
                }
                
                System.debug('qli'+qli);
                quoteLineItemsToUpsert.add(qli);
            }
            
            System.debug('Before upsert - rowIdToQliMap size: ' + rowIdToQliMap.size()); // Debug line
            
            if (!quoteLineItemsToUpsert.isEmpty()) {
                Database.upsert(quoteLineItemsToUpsert, true);
            }
            
            System.debug('After upsert - rowIdToQliMap size: ' + rowIdToQliMap.size()); // Debug line
            
            if(discountPercent != null && discountPercent > 0 && discountAmount != null && discountAmount > 0){
                Quote quoteToUpdate = new Quote();
                quoteToUpdate.Id = quoteId;
                quoteToUpdate.Discount__c = discountPercent;
                quoteToUpdate.Discounted_Amount__c = discountAmount; 
                
                update quoteToUpdate;
                System.debug('Quote updated with discount: ' + discountPercent + '% and amount: ' + discountAmount);
            } else if (discountPercent == null || discountPercent == 0) {
                Quote quoteToUpdate = new Quote();
                quoteToUpdate.Id = quoteId;
                quoteToUpdate.Discount__c = null;
                quoteToUpdate.Discounted_Amount__c = null;
                
                update quoteToUpdate;
                System.debug('Quote discount cleared');
            }
            
            // Prepare return map with rowId to salesforceId mapping
            Map<String, String> rowIdToSalesforceIdMap = new Map<String, String>();
            for (String rowId : rowIdToQliMap.keySet()) {
                QuoteLineItem qli = rowIdToQliMap.get(rowId);
                if (qli.Id != null) {
                    rowIdToSalesforceIdMap.put(rowId, qli.Id);
                    System.debug('Mapping rowId: ' + rowId + ' to salesforceId: ' + qli.Id); // Debug line
                } else {
                    System.debug('QuoteLineItem ID is null for rowId: ' + rowId); // Debug line
                }
            }
            
            System.debug('Final rowIdToSalesforceIdMap: ' + rowIdToSalesforceIdMap);
            return rowIdToSalesforceIdMap;
            
        } catch (Exception ex) {
            System.debug('Error in createQuoteLineItems: ' + ex.getMessage() + ' - ' +  ex.getLineNumber());
            throw new AuraHandledException('Error while creating Quote Line Items: ' + ex.getMessage());
        }
    }
    
    @AuraEnabled(cacheable=true)
    public static List<PricebookEntry> searchProductItems(String searchKey) {
        Pricebook2 pb = [SELECT Id FROM Pricebook2 WHERE Name = 'Floor World Price Book' AND IsActive = true LIMIT 1];
        
        if (pb == null) {
            return new List<PricebookEntry>();
        }
        
        String query = '%' + searchKey + '%';
        
        return [SELECT Product2.Name, Product2.ProductCode, UnitPrice, Product2.Description, Product2.Family, Product2.Primary_Sale_Unit__c, Product2.Width_m__c,
                Product2.Average_Cost__c, Id
                FROM PricebookEntry 
                WHERE Pricebook2.Id =: pb.Id AND Product2.Name LIKE :query AND IsActive = true LIMIT 10];
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
        public String itemType;
        public Boolean isIndividualDiscount;
        public Integer rowNumber;
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
        public String family { get; set; }
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
        @AuraEnabled
        public Boolean isIndividualDiscount { get; set; }
        @AuraEnabled
        public Decimal averageCost { get; set; }
        @AuraEnabled
        public Decimal estExtendedCost { get; set; }
        @AuraEnabled
        public Integer rowNumber { get; set; }
    }
}