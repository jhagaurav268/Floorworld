import { LightningElement, api, track } from 'lwc';
import saveFiles from '@salesforce/apex/WorkOrderController.saveFiles';
import checkWorkStepStatus from '@salesforce/apex/WorkOrderController.checkWorkStepStatus';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { NavigationMixin } from 'lightning/navigation';

export default class FileUploader extends NavigationMixin(LightningElement) {
    @api recordId;
    @track files = [];
    @track isLoading = false;
    @track showComponent = false;
    @track componentMessage;



  connectedCallback() {
        checkWorkStepStatus({ recordId: this.recordId, executionOrder: 3 }).then((result) => {
            console.log('result-->', result);
            if(result!=''){
            this.showComponent = false;
            this.componentMessage = result;
            }
            else{
            this.showComponent = true;
            }
        })
            .catch(error => {
                console.error('Error updating record:', error);
            });
    }

  handleFilesSelected(event) {
    const selectedFiles = Array.from(event.target.files);

    const readPromises = selectedFiles.map(file => {
        return new Promise((resolve, reject) => {
            const reader = new FileReader();
            reader.onload = () => {
                const base64 = reader.result.split(',')[1];
                resolve({
                    name: file.name, 
                    type: file.type,
                    base64Data: base64,
                    previewUrl: file.type.startsWith('image/') ? reader.result : null
                });
            };
            reader.onerror = error => reject(error);
            reader.readAsDataURL(file);
        });
    });

    Promise.all(readPromises).then(newFiles => {
        console.log('newFiles:', JSON.stringify(newFiles));
        this.files = [...this.files, ...newFiles];
    }).catch(error => {
        console.error('Error reading files:', error);
        this.showToast('Error', 'Failed to read file(s)', 'error');
    });

    event.target.value = null;
}

    handleSave() {
        this.isLoading = true;
        if (!this.recordId || !this.files.length) {
            this.showToast('Warning', 'No files or record ID missing', 'warning');
            return;
        }

        const payload = this.files.map(f => ({
            name: f.name,
            type: f.type,
            base64Data: f.base64Data
        }));
        console.log('payload--->', JSON.stringify(payload));

        saveFiles({ recordId: this.recordId, filesData: JSON.stringify(payload) })
            .then(() => {
                this.isLoading = false;
                this.files = [];
                this[NavigationMixin.Navigate]({
                    "type": "standard__webPage",
                    "attributes": {
                        "url": `com.salesforce.fieldservice://v1/sObject/${this.recordId}`
                    }
                });
                this.showToast('Success', 'Files uploaded successfully', 'success');
            })
            .catch(error => {
                this.isLoading = false;
                console.error('Upload error:', error);
                this.showToast('Error', error.type, 'error');
            });
    }

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }
    
}