import { LightningElement, track, api } from 'lwc';
import searchProductItems from '@salesforce/apex/QuoteController.searchProductItems';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import upsertQuoteLineItems from '@salesforce/apex/QuoteController.upsertQuoteLineItems';
import getExistingQuoteLineItems from '@salesforce/apex/QuoteController.getExistingQuoteLineItems';

const PRODUCT_FAMILIES = {
    WALL_TO_WALL: ['Wall to Wall', 'Sheet Vinyl', 'Grass'],
    DECKING: ['Decking', 'Wood Flooring', 'LVT']
};

const TAX_RATE = 0.05;
const DISCOUNT_FAMILY = 'Discount';

export default class FloorWorldCarpetSolution extends LightningElement {
    @api recordId;

    @track tableData = [];
    @track selectedDiscount = '';
    @track rate = '';
    @track filteredProducts = [];
    @track selectedRowIndex = -1;

    rowId = 1;
    copyOfSelectedRow = null;
    isLoading = false;
    searchTimeout = null;

    get discountOptions() {
        return [
            { label: 'None', value: '' },
            { label: 'Discount 5%', value: '5' },
            { label: 'Discount 10%', value: '10' },
            { label: 'Discount 15%', value: '15' },
            { label: 'Discount 25%', value: '25' },
        ];
    }

    connectedCallback() {
        this.initializeComponent();
    }

    async initializeComponent() {
        this.isLoading = true;
        try {
            await this.loadExistingQuoteLineItems();
        } catch (error) {
            this.showToast('Error', 'Failed to load existing items', 'error');
        } finally {
            this.isLoading = false;
        }
    }

    async loadExistingQuoteLineItems() {
        try {
            const data = await getExistingQuoteLineItems({ quoteId: this.recordId });
            const existingRows = data.map(item => this.mapItemToTableRow(item));

            this.tableData = existingRows.length > 0 ? existingRows : [this.createNewRow()];
        } catch (error) {
            this.showToast('Error', error.body?.message || 'Failed to load items', 'error');
            this.tableData = [this.createNewRow()];
        }
    }

    createNewRow() {
        return {
            id: this.generateRowId(),
            salesforceId: null,
            location: '',
            itemInput: '',
            description: '',
            netArea: '',
            wastage: '',
            length: '',
            widthM: '',
            totalArea: '',
            quantity: '',
            quantitySqm: '',
            units: '',
            rate: '',
            unitPriceSub: '',
            amount: '',
            taxAmount: '',
            grossAmount: '',
            estExtendedCost: '',
            costEstimateType: '',
            estimateType: '',
            family: '',
            selectedItemId: '',
            averageCost: '',
            costPricePerUnit: '',
            costPrice: '',
            isSuggestionsVisible: false,
            editmode: true,
            readmode: false,
            isSelected: false,
            netAreaDisable: false,
            wastageDisable: true,
            lengthDisable: false
        };
    }

    mapItemToTableRow(item) {
        const isWallToWall = PRODUCT_FAMILIES.WALL_TO_WALL.includes(item.productFamily);
        const isDecking = PRODUCT_FAMILIES.DECKING.includes(item.productFamily);

        return {
            id: this.generateRowId(),
            salesforceId: item.salesforceId,
            location: item.location || '',
            itemInput: item.productName || '',
            description: item.productDescription || '',
            netArea: this.safeToString(item.netArea),
            wastage: this.safeToString(item.wastage),
            length: this.safeToString(item.length),
            widthM: this.safeToString(item.width),
            totalArea: this.safeToString(item.totalArea),
            quantity: this.safeToString(item.quantity),
            quantitySqm: this.safeToString(item.quantityArea),
            units: item.units || '',
            rate: this.safeToString(item.rate),
            unitPriceSub: this.safeToString(item.unitPrice),
            amount: this.safeToString(item.amount),
            taxAmount: this.safeToString(item.taxAmount),
            grossAmount: this.safeToString(item.grossAmount),
            estExtendedCost: this.safeToString(item.estExtendedCost),
            costEstimateType: 'Custom',
            estimateType: item.estimateType || '',
            family: item.family || '',
            selectedItemId: item.productId,
            averageCost: this.safeToString(item.averageCost),
            costPricePerUnit: this.safeToString(item.costPricePerUnit),
            costPrice: this.safeToString(item.costPrice),
            isSuggestionsVisible: false,
            editmode: false,
            readmode: true,
            isSelected: false,
            netAreaDisable: isWallToWall,
            wastageDisable: true,
            lengthDisable: isDecking
        };
    }

    generateRowId() {
        return this.rowId++;
    }

    safeToString(value) {
        return value?.toString() || '';
    }

    safeParseFloat(value, defaultValue = 0) {
        const parsed = parseFloat(value);
        return isNaN(parsed) ? defaultValue : parsed;
    }

    handleDiscountChange(event) {
        this.selectedDiscount = event.detail.value;
        this.rate = this.selectedDiscount;
        this.applyDiscount();
    }

    handleRateChange(event) {
        this.rate = event.target.value;
        console.log('this.rate ', this.rate);
        this.applyDiscount();
    }

    applyDiscount() {
        if (this.rate && this.rate !== '') {
            const discountRate = this.safeParseFloat(this.rate);
            console.log('discountRate ', discountRate);

            if (discountRate > 0) {
                this.addDiscountRow(discountRate);
            }
        }
    }

    addDiscountRow(discountRate) {
        const totalGrossAmount = (this.calculateTotalGrossAmount() * discountRate) / 100;
        const totalRate = (this.calculateTotalRate() * discountRate) / 100;
        const unitPriceSub = (this.calculateunitPriceSub() * discountRate) / 100;
        const amount = (this.calculateAmount() * discountRate) / 100;
        const taxAmount = (this.calculateTaxAmount() * discountRate) / 100;

        if (totalGrossAmount <= 0) {
            this.showToast('Warning', 'No items available to apply discount. Please add items first.', 'warning');
            return;
        }

        this.tableData = this.tableData.filter(row => row.family !== DISCOUNT_FAMILY);

        const discountRow = this.createDiscountRow(discountRate, totalGrossAmount, totalRate, unitPriceSub, amount, taxAmount);

        this.tableData = [...this.tableData, discountRow];
        this.showToast('Success', `${discountRate}% discount applied successfully!`, 'success');
    }

    createDiscountRow(discountRate, totalGrossAmount, totalRate, unitPriceSub, amount, taxAmount) {

        return {
            ...this.createNewRow(),
            location: 'Discount',
            itemInput: `Discount (${discountRate}%)`,
            description: `${discountRate}% discount on total amount`,
            quantity: 1,
            rate: -totalRate.toFixed(2),
            unitPriceSub: -unitPriceSub.toFixed(2),
            amount: -amount.toFixed(2),
            taxAmount: -taxAmount.toFixed(2),
            grossAmount: -totalGrossAmount.toFixed(2),
            costEstimateType: 'Discount',
            estimateType: 'Discount',
            family: DISCOUNT_FAMILY,
            editmode: false,
            readmode: true,
            netAreaDisable: true,
            lengthDisable: true
        };
    }

    calculateTotalGrossAmount() {
        return this.tableData
            .filter(row => row.family !== DISCOUNT_FAMILY && row.grossAmount)
            .reduce((total, row) => total + this.safeParseFloat(row.grossAmount), 0);
    }

    calculateTotalRate() {
        return this.tableData
            .filter(row => row.family !== DISCOUNT_FAMILY && row.rate)
            .reduce((total, row) => total + this.safeParseFloat(row.rate), 0);
    }

    calculateunitPriceSub() {
        return this.tableData
            .filter(row => row.family !== DISCOUNT_FAMILY && row.unitPriceSub)
            .reduce((total, row) => total + this.safeParseFloat(row.unitPriceSub), 0);
    }

    calculateAmount() {
        return this.tableData
            .filter(row => row.family !== DISCOUNT_FAMILY && row.amount)
            .reduce((total, row) => total + this.safeParseFloat(row.amount), 0);
    }

    calculateTaxAmount() {
        return this.tableData
            .filter(row => row.family !== DISCOUNT_FAMILY && row.taxAmount)
            .reduce((total, row) => total + this.safeParseFloat(row.taxAmount), 0);
    }

    recalculateDiscount() {
        if (this.rate && this.rate !== '') {
            this.addDiscountRow(this.safeParseFloat(this.rate));
        }
    }

    handleInputChange(event) {
        const { id: rowId, field } = event.target.dataset;
        const value = event.target.value;

        this.updateTableRow(parseInt(rowId), field, value);
        this.scheduleDiscountRecalculation(field);
    }

    updateTableRow(rowId, field, value) {
        this.tableData = this.tableData.map(row => {
            if (row.id === rowId) {
                const updatedRow = { ...row, [field]: value };
                this.performCalculations(updatedRow, field);
                this.updateFieldStates(updatedRow, field);
                return updatedRow;
            }
            return row;
        });
    }

    scheduleDiscountRecalculation(field) {
        const fieldsToRecalculate = ['amount', 'grossAmount', 'quantity', 'rate', 'unitPriceSub'];
        if (fieldsToRecalculate.includes(field)) {
            setTimeout(() => this.recalculateDiscount(), 100);
        }
    }

    updateFieldStates(row, field) {
        if (field === 'quantity' && !row.units) {
            row.units = 'SqM';
        }

        if (field !== 'length' && row.totalArea) {
            row.wastageDisable = false;
        } else if (!row.totalArea) {
            row.wastageDisable = true;
        }
    }

    performCalculations(row, changedField) {
        const calculations = {
            netArea: () => this.calculateAreaFromDimensions(row),
            wastage: () => this.calculateAreaFromDimensions(row),
            length: () => this.calculateAreaFromDimensions(row)
        };

        if (calculations[changedField]) {
            calculations[changedField]();
        }

        this.calculateQuantities(row);
        this.calculatePricing(row);
        this.calculateCosts(row);
        this.formatNumbers(row);
    }

    calculateAreaFromDimensions(row) {
        if (row.length && row.widthM) {
            row.netArea = (this.safeParseFloat(row.length) * this.safeParseFloat(row.widthM)).toString();
        }
        row.totalArea = this.calculateTotalArea(row.netArea, row.wastage).toString();
    }

    calculateTotalArea(netArea, wastage) {
        if (!netArea) return 0;
        const net = this.safeParseFloat(netArea);
        const waste = this.safeParseFloat(wastage);
        return net + (net * waste / 100);
    }

    calculateQuantities(row) {
        if (row.totalArea && row.units) {
            const totalArea = this.safeParseFloat(row.totalArea);
            const unitValue = this.extractUnitValue(row.units);

            row.quantity = Math.ceil(totalArea / unitValue).toString();
            row.quantitySqm = (this.safeParseFloat(row.quantity) * unitValue).toFixed(2);
        } else if (row.widthM && !row.units && row.totalArea) {
            const totalArea = this.safeParseFloat(row.totalArea);
            const width = this.safeParseFloat(row.widthM);

            row.quantity = Math.ceil(totalArea / width).toString();
            row.quantitySqm = (this.safeParseFloat(row.quantity) * width).toFixed(2);
        }
    }

    calculatePricing(row) {
        const unitPrice = this.safeParseFloat(row.unitPriceSub);

        if (unitPrice > 0) {
            if (row.units) {
                const unitValue = this.extractUnitValue(row.units);
                row.rate = (unitPrice * unitValue).toFixed(2);
            } else if (row.widthM) {
                row.rate = (unitPrice * this.safeParseFloat(row.widthM)).toFixed(2);
            }
        }

        const quantitySqm = this.safeParseFloat(row.quantitySqm);
        const quantity = this.safeParseFloat(row.quantity);
        const rate = this.safeParseFloat(row.rate);

        if (quantitySqm && unitPrice) {
            row.amount = (quantitySqm * unitPrice).toFixed(2);
        } else if (quantity && rate) {
            row.amount = (quantity * rate).toFixed(2);
        }

        const amount = this.safeParseFloat(row.amount);
        if (amount) {
            row.taxAmount = (amount * TAX_RATE).toFixed(2);
            row.grossAmount = (amount * (1 + TAX_RATE)).toFixed(2);
        }
    }

    calculateCosts(row) {
        const averageCost = this.safeParseFloat(row.averageCost);
        const quantity = this.safeParseFloat(row.quantity);
        if (averageCost && quantity) {
            row.estExtendedCost = (averageCost * quantity).toFixed(2);
        }

        const costPricePerUnit = this.safeParseFloat(row.costPricePerUnit);
        if (costPricePerUnit) {
            if (row.widthM) {
                row.costPrice = (this.safeParseFloat(row.widthM) * costPricePerUnit).toFixed(2);
            } else if (row.units) {
                const unitValue = this.extractUnitValue(row.units);
                row.costPrice = (unitValue * costPricePerUnit).toFixed(2);
            }
        }

        if (row.rate && row.quantity) {
            row.costEstimateType = 'Custom';
        }
    }

    formatNumbers(row) {
        const fieldsToFormat = ['totalArea', 'rate', 'amount', 'taxAmount', 'grossAmount', 'estExtendedCost', 'quantitySqm'];
        fieldsToFormat.forEach(field => {
            if (row[field]) {
                row[field] = this.safeParseFloat(row[field]).toFixed(2);
            }
        });
    }

    extractUnitValue(units) {
        if (typeof units === 'string') {
            const match = units.match(/^(\d+(?:\.\d+)?)/);
            return match ? parseFloat(match[1]) : 1;
        }
        return this.safeParseFloat(units, 1);
    }

    handleSearchChange(event) {
        const rowId = parseInt(event.target.dataset.id);
        const searchTerm = event.target.value;

        this.updateRowSearchTerm(rowId, searchTerm);
        this.debouncedSearch(searchTerm);
    }

    updateRowSearchTerm(rowId, searchTerm) {
        this.tableData = this.tableData.map(row =>
            row.id === rowId ? { ...row, itemInput: searchTerm } : row
        );
    }

    debouncedSearch(searchTerm) {
        clearTimeout(this.searchTimeout);

        if (searchTerm.length > 0) {
            this.searchTimeout = setTimeout(() => {
                this.loadProductSuggestions(searchTerm);
            }, 300);
        } else {
            this.filteredProducts = [];
        }
    }

    async loadProductSuggestions(searchKey) {
        try {
            const result = await searchProductItems({ searchKey });
            this.filteredProducts = result || [];
        } catch (error) {
            console.error('Error fetching product suggestions', error);
            this.filteredProducts = [];
        }
    }

    handleProductSelect(event) {
        const productId = event.target.dataset.id;
        const rowIndex = parseInt(event.target.closest('tr').dataset.index);
        const product = this.filteredProducts.find(p => p.Id === productId);

        if (product && this.tableData[rowIndex]) {
            this.applyProductToRow(rowIndex, product);
            this.hideAllSuggestions();
        }
    }

    applyProductToRow(rowIndex, product) {
        const row = { ...this.tableData[rowIndex] };
        const productData = product.Product2;

        Object.assign(row, {
            itemInput: productData.Name,
            description: productData.Description || '',
            units: productData.Primary_Sale_Unit__c || '',
            widthM: productData.Width_m__c || '',
            family: productData.Family || '',
            selectedItemId: product.Id,
            unitPriceSub: product.UnitPrice || '',
            averageCost: productData.Average_Cost__c || 0,
            costPricePerUnit: product.Cost_Prize__c || '',
            rate: product.UnitPrice || ''
        });

        this.setFieldStatesForFamily(row);

        this.performCalculations(row, 'productSelect');

        this.tableData = [
            ...this.tableData.slice(0, rowIndex),
            row,
            ...this.tableData.slice(rowIndex + 1)
        ];
    }

    setFieldStatesForFamily(row) {
        const isWallToWall = PRODUCT_FAMILIES.WALL_TO_WALL.includes(row.family);
        const isDecking = PRODUCT_FAMILIES.DECKING.includes(row.family);

        row.netAreaDisable = isWallToWall;
        row.lengthDisable = isDecking;
    }

    hideAllSuggestions() {
        this.tableData = this.tableData.map(row => ({
            ...row,
            isSuggestionsVisible: false
        }));
        this.filteredProducts = [];
    }

    handleFocus(event) {
        const rowId = parseInt(event.target.dataset.id);
        this.toggleSuggestionVisibility(rowId, true);
    }

    handleBlur(event) {
        const rowId = parseInt(event.target.dataset.id);
        setTimeout(() => {
            this.toggleSuggestionVisibility(rowId, false);
        }, 200);
    }

    toggleSuggestionVisibility(rowId, isVisible) {
        this.tableData = this.tableData.map(row =>
            row.id === rowId ? { ...row, isSuggestionsVisible: isVisible } : row
        );
    }

    handleRowSelection(event) {
        const selectedIndex = parseInt(event.currentTarget.dataset.index);
        this.selectedRowIndex = selectedIndex;

        this.tableData = this.tableData.map((row, index) => ({
            ...row,
            isSelected: index === selectedIndex
        }));
    }

    handleAddRow() {
        if (this.selectedRowIndex === -1) return;

        const selectedRow = this.tableData[this.selectedRowIndex];
        const isEditMode = selectedRow.editmode;

        this.tableData[this.selectedRowIndex] = {
            ...selectedRow,
            editmode: !isEditMode,
            readmode: isEditMode
        };

        if (!isEditMode) {
            this.copyOfSelectedRow = JSON.parse(JSON.stringify(selectedRow));
        }

        this.tableData = [...this.tableData];
    }

    handleCancel() {
        if (this.selectedRowIndex === -1 || !this.copyOfSelectedRow) return;

        this.tableData[this.selectedRowIndex] = {
            ...this.copyOfSelectedRow,
            editmode: false,
            readmode: true
        };
        this.tableData = [...this.tableData];
    }

    handleInsert() {
        if (this.selectedRowIndex === -1) return;

        const newRow = this.createNewRow();
        const insertIndex = this.selectedRowIndex + 1;

        this.tableData = [
            ...this.tableData.slice(0, insertIndex).map(row => ({ ...row, isSelected: false })),
            newRow,
            ...this.tableData.slice(insertIndex).map(row => ({ ...row, isSelected: false }))
        ];

        this.selectedRowIndex = insertIndex;
        this.copyOfSelectedRow = JSON.parse(JSON.stringify(newRow));
    }

    handleRemove() {
        if (this.selectedRowIndex <= 0 || this.tableData.length <= 1) return;

        const selectedRow = this.tableData[this.selectedRowIndex];

        if (selectedRow.item === 'Discount' || selectedRow.description?.includes('discount')) {
            this.tableData = this.tableData.filter((_, index) => index !== this.selectedRowIndex);
            this.selectedRowIndex = Math.max(0, this.selectedRowIndex - 1);
            this.rate = 0;
            this.discountDropdownValue = null;
            return;
        }

        this.tableData = this.tableData.filter((_, index) => index !== this.selectedRowIndex);
        this.selectedRowIndex = Math.max(0, this.selectedRowIndex - 1);

        this.recalculateDiscount();
    }


    async handleSave() {
        this.isLoading = true;
        try {
            await this.createQuoteLineItemData();
        } catch (error) {
            this.showToast('Error', 'Failed to save items', 'error');
        } finally {
            this.isLoading = false;
        }
    }

    async createQuoteLineItemData() {
        const dataObj = this.buildQuoteLineItems();
        console.log('dataObj ', JSON.stringify(dataObj));
        const totalDiscountAmount = this.calculateDiscountAmount();
        const discountPercent = this.safeParseFloat(this.rate);

        try {
            await upsertQuoteLineItems({
                lineItemsData: dataObj,
                discountPercent,
                discountAmount: totalDiscountAmount
            });
            this.showToast('Success', 'Quote Line Items saved successfully!', 'success');
        } catch (error) {
            throw new Error(error.body?.message || 'Failed to save items');
        }
    }

    buildQuoteLineItems() {
        return this.tableData
            .filter(row => row.location !== 'Discount')
            .map(product => ({
                salesforceId: product.salesforceId,
                quoteId: this.recordId,
                location: product.location || '',
                productId: product.selectedItemId || '',
                productDescription: product.description || '',
                netArea: this.safeParseFloat(product.netArea),
                wastage: this.safeParseFloat(product.wastage),
                length: product.length || '',
                width: product.widthM || '',
                totalArea: this.safeParseFloat(product.totalArea),
                rate: this.safeParseFloat(product.rate),
                productUnitPrice: this.safeParseFloat(product.unitPriceSub),
                quantity: this.safeParseFloat(product.quantity, 1),
                quantityArea: this.safeParseFloat(product.quantitySqm),
                price: this.safeParseFloat(product.amount),
                taxAmount: this.safeParseFloat(product.taxAmount),
                grossAmount: this.safeParseFloat(product.grossAmount),
                estExtendedCost: this.safeParseFloat(product.estExtendedCost),
                discountPercentage: this.safeParseFloat(product.discount) * -1,
                discountId: product.discountId || '',
                rowId: product.id.toString(),
                units: product.units || '',
                costPrice: product.costPrice || '',
                type: product.family || ''
            }));
    }

    calculateDiscountAmount() {
        return this.tableData
            .filter(row => row.location === 'Discount' && row.amount)
            .reduce((total, row) => total + Math.abs(this.safeParseFloat(row.amount)), 0);
    }

    showToast(title, message, variant, mode = 'dismissable') {
        this.dispatchEvent(new ShowToastEvent({
            title,
            message,
            variant,
            mode
        }));
    }
}