trigger ServiceAppointmentTrigger on ServiceAppointment(after Insert, after update, after delete, before Insert, before update, before delete){
    if (Floorworld_Utility.ignorePaymentTrigger == false) {
        TriggerFactory.createHandler(ServiceAppointment.sObjectType);
    }
}