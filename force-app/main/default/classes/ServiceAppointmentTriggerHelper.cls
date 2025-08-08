public class ServiceAppointmentTriggerHelper {
        public static void statusUpdate(List<ServiceAppointment> allAppointments, Map<Id, ServiceAppointment> oldMap) {
        List<ServiceAppointment> appointmentsToUpdate = new List<ServiceAppointment>();
        for (ServiceAppointment sa : allAppointments) {
            System.debug('sa.Status >> ' + sa.Status + ' << oldMap Status >> ' + oldMap.get(sa.Id).Status);
            if (String.isNotBlank(sa.Status) && sa.Status != oldMap.get(sa.Id).Status && sa.Status == 'Scheduled' && oldMap.get(sa.Id).Status != 'Dispatched' && 
                String.isNotBlank(sa.ParentRecordId)) {
                    ServiceAppointment srv = new ServiceAppointment(Id = sa.Id);
                    srv.Status = 'Dispatched';
                    appointmentsToUpdate.add(srv);
                }
        }
        
        System.debug('appointmentsToUpdate: >> ' + appointmentsToUpdate); 
        if (!appointmentsToUpdate.isEmpty()) {
            update appointmentsToUpdate;
        }
    }
    
    public static void throwErrorOnUpdate(List<ServiceAppointment> newAppointments, Map<Id, ServiceAppointment> oldMap) {
        Set<Id> workOrderIds = new Set<Id>();
        Map<Id, WorkOrder> workOrderMap = new Map<Id, WorkOrder>([SELECT Id,Status FROM WorkOrder WHERE Status=:'In Progress']);
        for(ServiceAppointment saObj :newAppointments){
            if(saObj.status == 'In Progress' && saObj.SchedStartTime != null && saObj.SchedStartTime != oldMap.get(saObj.Id).SchedStartTime && saObj.SchedEndTime != null && saObj.SchedEndTime != oldMap.get(saObj.Id).SchedEndTime && String.isNotBlank(saObj.ParentRecordId)){
               WorkOrder workOrderObj = workOrderMap.get(saObj.ParentRecordId);
               if(workOrderObj.status == 'In Progress'){
                  saObj.addError('You can not Re-scheduled Appintment after check In.');                    
                }
            }
        }
    }
}