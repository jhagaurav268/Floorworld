trigger SiteVisitTrigger on Site_Visit__c (before insert, before update, after insert, after update){
    if (Trigger.isBefore) {
        if (Trigger.isInsert) {
        }
        if (Trigger.isUpdate) {
            
        }
    } else if (Trigger.isAfter) {
        if (Trigger.isInsert) {
            SiteVisitTriggerHandler.createWorkOrders(Trigger.New);
        }
        if (Trigger.isUpdate) {
        }
    }
}