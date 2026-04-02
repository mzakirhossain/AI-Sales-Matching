import { LightningElement, track } from 'lwc';
import processUploads from '@salesforce/apex/AI_DataImportController.processUploads';

import runAIMatching from '@salesforce/apex/AIMatchingController.startProcess';
import getResults from '@salesforce/apex/AIMatchingController.getResults';
import getPrevResults from '@salesforce/apex/AIMatchingController.getPrevResults';

import { ShowToastEvent } from 'lightning/platformShowToastEvent';

export default class lwcAIMatchinSalesOps extends LightningElement {

    // ----------------------------
    // IMPORT SECTION
    // ----------------------------
    @track salesforceJson;
    @track listingsJson;
    @track fileNames = [];
    @track isLoading = false;

    // ----------------------------
    // AI RESULTS
    // ----------------------------
    @track results = [];
    processId;
    isRunning = false;

    // ----------------------------
    // DATATABLE COLUMNS
    // ----------------------------
    columns = [
        {
            label: 'Lead',
            fieldName: 'leadUrl',
            type: 'url',
            typeAttributes: {
                label: { fieldName: 'leadName' },
                target: '_blank'
            }
        },
        { label: 'Priority', fieldName: 'Priority__c' },
        { label: 'Agent', fieldName: 'Assigned_Agent_Name__c' },
        { label: 'Insight', fieldName: 'Insights__c' }
    ];

    // =========================================================
    // 🔥 LOAD PREVIOUS RESULTS ON PAGE LOAD
    // =========================================================
    connectedCallback() {
        this.loadPreviousResults();
    }

    loadPreviousResults() {
        // pass null or empty processId → Apex should return latest records
        getPrevResults()
            .then(data => {
                this.results = this.transform(data);
            })
            .catch(err => {
                console.error('History load error', err);
            });
    }

    // ----------------------------
    // FILE HANDLING
    // ----------------------------
    handleDragOver(evt) {
        evt.preventDefault();
    }

    handleDrop(evt) {
        evt.preventDefault();
        this.handleFileList(evt.dataTransfer.files);
    }

    handleFiles(evt) {
        this.handleFileList(evt.target.files);
    }

    handleFileList(files) {
        [...files].forEach(file => {

            if (!file.name.endsWith('.json')) {
                this.toast('Error', `Invalid file type: ${file.name}`, 'error');
                return;
            }

            this.fileNames.push(file.name);

            const reader = new FileReader();
            reader.onload = () => {
                if (file.name.includes('Salesforce')) {
                    this.salesforceJson = reader.result;
                } else if (file.name.includes('Listing')) {
                    this.listingsJson = reader.result;
                }
            };
            reader.readAsText(file);
        });
    }

    // ----------------------------
    // IMPORT
    // ----------------------------
    startImport() {
        if (!this.salesforceJson && !this.listingsJson) {
            this.toast('Error', 'Upload at least one JSON file.', 'error');
            return;
        }

        this.isLoading = true;

        processUploads({
            salesforceJson: this.salesforceJson,
            listingsJson: this.listingsJson
        })
            .then(() => {
                this.isLoading = false;
                this.toast('Success', 'Import completed', 'success');
            })
            .catch(err => {
                this.isLoading = false;
                this.toast('Error', err.body?.message || err.message, 'error');
            });
    }

    // ----------------------------
    // RUN AI
    // ----------------------------
    handleRunAI() {
        this.isRunning = true;
        this.results = [];

        runAIMatching()
            .then(id => {
                this.processId = id;

                setTimeout(() => {
                    this.checkResults();
                }, 5000);
            })
            .catch(err => {
                this.isRunning = false;
                this.toast('Error', err.body?.message || err.message, 'error');
            });
    }

    // ----------------------------
    // POLLING RESULTS
    // ----------------------------
    checkResults() {
        const interval = setInterval(() => {

            getResults({ processId: this.processId })
                .then(data => {

                    if (data && data.length > 0) {

                        this.results = this.transform(data);

                        this.isRunning = false;
                        clearInterval(interval);

                        this.toast('Success', 'AI matching is still in progress. Please wait a few moments and refresh the page to see the latest updates.', 'success');
                    }
                })
                .catch(err => {
                    this.isRunning = false;
                    clearInterval(interval);
                    this.toast('Error', err.body?.message || err.message, 'error');
                });

        }, 3000);
    }

    // ----------------------------
    // DATA TRANSFORMER (REUSABLE)
    // ----------------------------
    transform(data) {
        return data.map(r => ({
            ...r,
            leadUrl: '/' + r.Lead__c,
            leadName: r.Lead__r?.Name || r.Lead__c,
            parsedListings: (() => {
                try {
                    return JSON.parse(r.Listing_log__c || '[]');
                } catch (e) {
                    return [];
                }
            })()
        }));
    }

    // ----------------------------
    // TOAST
    // ----------------------------
    toast(title, message, variant) {
        this.dispatchEvent(
            new ShowToastEvent({
                title,
                message,
                variant
            })
        );
    }
}