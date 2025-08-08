trigger WorkOrderTrigger on WorkOrder (before insert, before update, after insert, after update){
    if (Trigger.isBefore) {
        if (Trigger.isInsert) {
        }
        if (Trigger.isUpdate) {
            
        }
    } else if (Trigger.isAfter) {
        if (Trigger.isInsert) {
            WorkOrderTriggerHandler.createServiceAppointment(Trigger.New);
            WorkOrderTriggerHandler.createSurveyInvitations(Trigger.New);
        }
        if (Trigger.isUpdate) {
        }
    }
}