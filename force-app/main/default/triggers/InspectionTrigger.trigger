trigger InspectionTrigger on Inspection__c (before insert, before update, after insert, after update){
    if (Trigger.isBefore) {
        if (Trigger.isInsert) {
        }
        if (Trigger.isUpdate) {
            
        }
    } else if (Trigger.isAfter) {
        if (Trigger.isInsert) {
            InspectionTriggerHandler.createWorkOrders(Trigger.New);
        }
        if (Trigger.isUpdate) {
        }
    }
}