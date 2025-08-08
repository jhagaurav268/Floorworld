public class ServiceAppointmentTriggerHandler implements TriggerInterface{
    public void beforeInsert(List<SObject> newList) {}
    public void beforeUpdate(List<SObject> newList, Map<Id, SObject> oldMap) {}
    
    public void afterInsert(List<SObject> newList) {
    }
    
    public void afterUpdate(List<SObject> newList, Map<Id, SObject> oldMap) {
        List<ServiceAppointment> newAppointments = (List<ServiceAppointment>) newList;
        Map<Id, ServiceAppointment> oldAppointments = (Map<Id, ServiceAppointment>) oldMap;
        ServiceAppointmentTriggerHelper.statusUpdate(newAppointments,oldAppointments);
        ServiceAppointmentTriggerHelper.throwErrorOnUpdate(newAppointments,oldAppointments);
    }
    
    public void beforeDelete(List<SObject> oldList, Map<Id, SObject> oldMap) {}
    
    public void afterDelete(List<SObject> oldList, Map<Id, SObject> oldMap) {}
    
}