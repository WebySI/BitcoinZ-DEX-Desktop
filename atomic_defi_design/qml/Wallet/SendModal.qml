import QtQuick 2.15
import QtQuick.Layouts 1.15
import QtQuick.Controls 2.15

import "../Components"
import "../Constants"

BasicModal {
    id: root

    readonly property bool empty_data: !send_result || !send_result.withdraw_answer

    property alias address_field: input_address.field
    property alias amount_field: input_amount.field
    property bool needFix: false
    property bool errorView: false
    property var address_data


    onClosed: reset()
    closePolicy: Popup.NoAutoClose

    // Local
    readonly property var default_send_result: ({ has_error: false, error_message: "",
                                                    withdraw_answer: {
                                                        total_amount_fiat: "", tx_hex: "", date: "", "fee_details": { total_fee: "" }
                                                    },
                                                    explorer_url: "", max: false })
    property var send_result: default_send_result


    readonly property bool is_send_busy: api_wallet_page.is_send_busy
    property var send_rpc_result: api_wallet_page.send_rpc_data
    readonly property bool is_validate_address_busy: api_wallet_page.validate_address_busy 
    readonly property bool is_convert_address_busy: api_wallet_page.convert_address_busy
    readonly property string address: api_wallet_page.converted_address
    onIs_validate_address_busyChanged: {
        console.log("Address busy changed to === %1".arg(is_validate_address_busy))
        if(!is_validate_address_busy) {
            address_data = api_wallet_page.validate_address_data
            if (address_data.reason!=="") {
                errorView = true
                reason.text = address_data.reason
            }else {
                errorView = false
            }
            if(address_data.convertible) {
                reason.text =  address_data.reason
                if(needFix!==true)
                    needFix = true
            }
        }
    }
    onIs_convert_address_busyChanged: {
        if(!is_convert_address_busy){
            if(needFix===true) {
                needFix = false
                input_address.field.text = api_wallet_page.converted_address
            }
        }
    }

    readonly property bool auth_succeeded: api_wallet_page.auth_succeeded

    readonly property bool is_broadcast_busy: api_wallet_page.is_broadcast_busy
    property string broadcast_result: api_wallet_page.broadcast_rpc_data
    property bool async_param_max: false

    onSend_rpc_resultChanged: {
        if (is_send_busy === false) {
            return
        }

        // Local var, faster
        const result = General.clone(send_rpc_result)

        if(result.error_code) {
            root.close()
            console.log("Send Error:", result.error_code, " Message:", result.error_message)
            toast.show(qsTr("Failed to send"), General.time_toast_important_error, result.error_message)
        }
        else {
            if(!result || !result.withdraw_answer) {
                reset()
                return
            }

            const max = async_param_max
            send_result.withdraw_answer.max = max

            if(max) input_amount.field.text = API.app.is_pin_cfg_enabled() ? General.absString(result.withdraw_answer.my_balance_change) : result.withdraw_answer.total_amount

            // Change page
            root.currentIndex = 1
        }

        send_result = result
    }

    onAuth_succeededChanged: {
        if (!auth_succeeded) {
            console.log("Double verification failed, cannot confirm sending.")
        }
        else {
            console.log("Double verification succeeded, validate sending.");
        }
    }

    onBroadcast_resultChanged: {
        if (is_broadcast_busy === false) {
            return
        }

        if(root.visible && broadcast_result !== "") {
            if(broadcast_result.indexOf("error") !== -1) {
                reset()
                showError(qsTr("Failed to Send"), General.prettifyJSON(broadcast_result))
            }
            else root.currentIndex = 2
        }
    }

    function prepareSendCoin(address, amount, with_fees, fees_amount, is_special_token, gas_limit, gas_price) {
        let max = input_max_amount.checked || parseFloat(current_ticker_infos.balance) === parseFloat(amount)

        // Save for later check
        async_param_max = max

        if(with_fees && max === false && !is_special_token)
            max = parseFloat(amount) + parseFloat(fees_amount) >= parseFloat(current_ticker_infos.balance)

        const fees_info = {
            fees_amount,
            gas_price,
            gas_limit: gas_limit === "" ? 0 : parseInt(gas_limit)
        }

        console.log("Passing fees info: ", JSON.stringify(fees_info))
        api_wallet_page.send(address, amount, max, with_fees, fees_info)
    }

    function sendCoin() {
        api_wallet_page.broadcast(send_result.withdraw_answer.tx_hex, false, send_result.withdraw_answer.max, input_amount.field.text)
    }

    function isSpecialToken() {
        return General.isTokenType(current_ticker_infos.type)
    }

    function isERC20() {
        return current_ticker_infos.type === "ERC-20" || current_ticker_infos.type === "BEP-20"
    }

    function hasErc20CaseIssue(addr) {
        if(!isERC20()) return false
        if(addr.length <= 2) return false

        addr = addr.substring(2) // Remove 0x
        return addr === addr.toLowerCase() || addr === addr.toUpperCase()
    }

    function reset() {
        send_result = default_send_result
        input_address.field.text = ""
        input_amount.field.text = ""
        input_custom_fees.field.text = ""
        input_custom_fees_gas.field.text = ""
        input_custom_fees_gas_price.field.text = ""
        custom_fees_switch.checked = false
        input_max_amount.checked = false
        root.currentIndex = 0
    }

    function feeIsHigherThanAmount() {
        if(!custom_fees_switch.checked) return false
        if(input_max_amount.checked) return false

        const amt = parseFloat(input_amount.field.text)
        const fee_amt = parseFloat(input_custom_fees.field.text)

        return amt < fee_amt
    }

    function hasFunds() {
        if(input_max_amount.checked) return true

        if(!General.hasEnoughFunds(true, api_wallet_page.ticker, "", "", input_amount.field.text))
            return false

        if(custom_fees_switch.checked) {
            if(isSpecialToken()) {
                const gas_limit = parseFloat(input_custom_fees_gas.field.text)
                const gas_price = parseFloat(input_custom_fees_gas_price.field.text)

                const unit = current_ticker_infos.type === "ERC-20" ? 1000000000 : 100000000
                const fee_parent_token = (gas_limit * gas_price)/unit

                const parent_ticker = current_ticker_infos.type === "ERC-20" ? "ETH" : "QTUM"
                if(api_wallet_page.ticker === parent_ticker) {
                    const amount = parseFloat(input_amount.field.text)
                    const total_needed = amount + fee_parent_token
                    if(!General.hasEnoughFunds(true, parent_ticker, "", "", total_needed.toString()))
                        return false
                }
                else {
                    if(!General.hasEnoughFunds(true, parent_ticker, "", "", fee_parent_token.toString()))
                        return false
                }
            }
            else {
                if(feeIsHigherThanAmount()) return false

                if(!General.hasEnoughFunds(true, api_wallet_page.ticker, "", "", input_custom_fees.field.text))
                    return false
            }
        }

        return true
    }

    function feesAreFilled() {
        return  (!custom_fees_switch.checked || (
                       (!isSpecialToken() && input_custom_fees.field.acceptableInput) ||
                       (isSpecialToken() && input_custom_fees_gas.field.acceptableInput && input_custom_fees_gas_price.field.acceptableInput &&
                                       parseFloat(input_custom_fees_gas.field.text) > 0 && parseFloat(input_custom_fees_gas_price.field.text) > 0)
                     )
                 )
    }

    function fieldAreFilled() {
        return input_address.field.text != "" &&
             (input_max_amount.checked || (input_amount.field.text != "" && input_amount.field.acceptableInput && parseFloat(input_amount.field.text) > 0)) &&
             feesAreFilled()
    }

    function setMax() {
        input_amount.field.text = current_ticker_infos.balance
    }

    // Inside modal
    // width: stack_layout.children[root.currentIndex].width + horizontalPadding * 2
    width: 650

    // Prepare Page
    ModalContent {
        Layout.fillWidth: true

        title: qsTr("Prepare to send ") + current_ticker_infos.name

        // Send address
        RowLayout {
            spacing: Style.buttonSpacing

            AddressFieldWithTitle {
                id: input_address
                Layout.alignment: Qt.AlignLeft
                title: qsTr("Recipient's address")
                field.placeholderText: qsTr("Enter address of the recipient")
                field.enabled: !root.is_send_busy
                field.onTextChanged: {
                    api_wallet_page.validate_address(field.text)
                }
            }

            DefaultButton {
                Layout.alignment: Qt.AlignRight | Qt.AlignBottom
                text: qsTr("Address Book")
                onClicked: contact_list.open()
                enabled: !root.is_send_busy
            }
        }

        // ERC-20 Lowercase issue
        RowLayout {
            Layout.fillWidth: true
            visible: errorView && input_address.field.text!=="" //isERC20() && input_address.field.text != "" && hasErc20CaseIssue(input_address.field.text)
            DefaultText {
                id: reason
                Layout.fillWidth: true
                wrapMode: Label.Wrap
                Layout.alignment: Qt.AlignLeft
                color: Style.colorRed
                text_value: qsTr("The address has to be mixed case.")
            }

            DefaultButton {
                visible: needFix
                Layout.preferredWidth: 70
                Layout.alignment: Qt.AlignRight
                text: qsTr("Fix")
                onClicked: {
                    api_wallet_page.convert_address(input_address.field.text, address_data.to_address_format)
                }
                enabled: !root.is_send_busy
            }
        }

        RowLayout {
            spacing: Style.buttonSpacing

            // Amount input
            AmountField {
                id: input_amount

                field.visible: !input_max_amount.checked
                title: qsTr("Amount to send")
                field.placeholderText: qsTr("Enter the amount to send")
                field.enabled: !root.is_send_busy
            }

            DefaultSwitch {
                id: input_max_amount
                Layout.alignment: Qt.AlignRight | Qt.AlignBottom
                text: qsTr("MAX")
                onCheckedChanged: input_amount.field.text = ""
                enabled: !root.is_send_busy
            }
        }

        // Custom fees switch
        DefaultSwitch {
            id: custom_fees_switch
            text: qsTr("Enable Custom Fees")
            onCheckedChanged: input_custom_fees.field.text = ""
            enabled: !root.is_send_busy
        }

        // Custom Fees section
        ColumnLayout {
            visible: custom_fees_switch.checked

            DefaultText {
                font.pixelSize: Style.textSize
                color: Style.colorRed
                text_value: qsTr("Only use custom fees if you know what you are doing!")
            }

            // Normal coins, Custom fees input
            AmountField {
                visible: !isSpecialToken()

                id: input_custom_fees
                title: qsTr("Custom Fee") + " [" + api_wallet_page.ticker + "]"
                field.placeholderText: qsTr("Enter the custom fee")
                field.enabled: !root.is_send_busy
            }

            // Token coins
            ColumnLayout {
                visible: isSpecialToken()

                // Gas input
                AmountIntField {
                    id: input_custom_fees_gas
                    title: qsTr("Gas Limit") + " [" + General.tokenUnitName(current_ticker_infos.type) + "]"
                    field.placeholderText: qsTr("Enter the gas limit")
                    field.enabled: !root.is_send_busy
                }

                // Gas price input
                AmountIntField {
                    id: input_custom_fees_gas_price
                    title: qsTr("Gas Price") + " [" + General.tokenUnitName(current_ticker_infos.type) + "]"
                    field.placeholderText: qsTr("Enter the gas price")
                    field.enabled: !root.is_send_busy
                }
            }
        }


        // Fee is higher than amount error
        DefaultText {
            id: fee_error
            wrapMode: Text.Wrap
            visible: feeIsHigherThanAmount()

            color: Style.colorRed

            text_value: qsTr("Custom Fee can't be higher than the amount")
        }

        // Not enough funds error
        DefaultText {
            wrapMode: Text.Wrap
            visible: !fee_error.visible && fieldAreFilled() && !hasFunds()

            color: Style.colorRed

            text_value: qsTr("Not enough funds.") + "\n" + qsTr("You have %1", "AMT TICKER").arg(General.formatCrypto("", API.app.get_balance(api_wallet_page.ticker), api_wallet_page.ticker))
        }

        DefaultBusyIndicator {
            visible: root.is_send_busy
        }

        // Buttons
        footer: [
            DefaultButton {
                text: qsTr("Close")
                Layout.fillWidth: true
                onClicked: root.close()
            },

            PrimaryButton {
                text: qsTr("Prepare")
                Layout.fillWidth: true

                enabled: fieldAreFilled() && hasFunds() && !errorView && !root.is_send_busy

                onClicked: prepareSendCoin(input_address.field.text, input_amount.field.text, custom_fees_switch.checked, input_custom_fees.field.text,
                                           isSpecialToken(), input_custom_fees_gas.field.text, input_custom_fees_gas_price.field.text)
            }
        ]

        ModalLoader { // Modal to pick up a contact's address.
            id: contact_list
            sourceComponent: SendModalContactList {
                onClosed: {
                    if (selected_address === "") {
                        return
                    }
                    input_address.field.text = selected_address
                    selected_address = ""
                    console.debug("SendModal: Selected %1 address from addressbook.".arg(input_address.field.text))
                }
            }
        }
    }

    // Send Page
    ModalContent {
        title: qsTr("Send")

        // Address
        TextEditWithTitle {
            title: qsTr("Recipient's address")
            text: input_address.field.text
        }

        // Amount
        TextEditWithTitle {
            title: qsTr("Amount")
            text: empty_data ? "" :
                  General.formatCrypto("", input_amount.field.text, api_wallet_page.ticker, send_result.withdraw_answer.total_amount_fiat, API.app.settings_pg.current_currency)
        }

        // Fees
        TextEditWithTitle {
            title: qsTr("Fees")
            text: empty_data ? "" :
                  General.formatCrypto("", send_result.withdraw_answer.fee_details.amount, current_ticker_infos.fee_ticker, send_result.withdraw_answer.fee_details.amount_fiat, API.app.settings_pg.current_currency)
        }

        // Date
        TextEditWithTitle {
            title: qsTr("Date")
            text: empty_data ? "" :
                  send_result.withdraw_answer.date
        }

        DefaultBusyIndicator {
            visible: root.is_broadcast_busy
        }

        // Buttons
        footer: [
            DefaultButton {
                text: qsTr("Back")
                Layout.fillWidth: true
                onClicked: root.currentIndex = 0
                enabled: !root.is_broadcast_busy
            },

            PrimaryButton {
                text: qsTr("Send")
                Layout.fillWidth: true
                onClicked: sendCoin()
                enabled: !root.is_broadcast_busy
            }
        ]
    }

    // Result Page
    SendResult {
        result: ({
            balance_change: empty_data ? "" : send_result.withdraw_answer.my_balance_change,
            fees: empty_data ? "" : send_result.withdraw_answer.fee_details.amount,
            date: empty_data ? "" : send_result.withdraw_answer.date
        })
        address: input_address.field.text
        tx_hash: broadcast_result
        custom_amount: input_amount.field.text

        function onClose() {
            root.close()
        }
    }
}
