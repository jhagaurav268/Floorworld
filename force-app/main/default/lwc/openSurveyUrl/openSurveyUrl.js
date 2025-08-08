import { LightningElement, api, wire, track } from 'lwc';
import { getRecord } from 'lightning/uiRecordApi';
import { NavigationMixin } from 'lightning/navigation';
import checkWorkStepStatus from '@salesforce/apex/WorkOrderController.checkWorkStepStatus';

const FIELDS = ['WorkOrder.Survey_URL__c'];

export default class OpenSurveyUrl extends NavigationMixin(LightningElement) {
    @api recordId;
    surveyUrl;
    @track showComponent = false;
    @track componentMessage;


    @wire(getRecord, { recordId: '$recordId', fields: FIELDS })
    handleRecord({ error, data }) {
        if (data) {
            this.surveyUrl = data.fields.Survey_URL__c?.value;
            this.validateWorkStep();
        } else if (error) {
            console.error('Failed to load Survey URL:', error);
        }
    }
    async validateWorkStep() {
        try {
            const response = await checkWorkStepStatus({ recordId: this.recordId, executionOrder: 2 });

            if (this.surveyUrl && response == '') {
                this[NavigationMixin.Navigate]({
                    type: 'standard__webPage',
                    attributes: {
                        url: this.surveyUrl
                    }
                });
            }
            else {
                this.showComponent = true;
                this.componentMessage = response;
            }
        } catch (error) {
            console.error('Error in checkWorkStepStatus:', error);
        }
    }
}