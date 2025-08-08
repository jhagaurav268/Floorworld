import { LightningElement, api, track } from 'lwc';
import { CloseActionScreenEvent } from 'lightning/actions';
import checkWorkStepStatus from '@salesforce/apex/WorkOrderController.checkWorkStepStatus';
import updateWorkOrder from '@salesforce/apex/WorkOrderController.checkIn';
import { NavigationMixin } from 'lightning/navigation';


export default class CheckIn extends NavigationMixin(LightningElement) {
    @api recordId;

    @track statusValue = 'In Progress';
    @track startDateTime = '';
    @track isLoading = false;

    connectedCallback() {
        const now = new Date();
        this.startDateTime = now.toISOString();
    }

    handleStatusChange(event) {
        this.statusValue = event.detail.value;
    }

    handleStartDateTimeChange(event) {
        this.startDateTime = event.detail.value;
    }

    handleSave() {
        this.isLoading = true;
        updateWorkOrder({
            recordId: this.recordId,
            statusValue: this.statusValue,
            startDateTime: this.startDateTime
        }).then(() => {
                this[NavigationMixin.Navigate]({
                    "type": "standard__webPage",
                    "attributes": {
                        "url": `com.salesforce.fieldservice://v1/sObject/${this.recordId}`
                    }
                });
                this.isLoading = false;
                console.log('Record updated successfully.');
            })
            .catch(error => {
                this.isLoading = false;
                console.error('Error updating record:', error);
            });
    }
}