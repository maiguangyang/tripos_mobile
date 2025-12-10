package com.example.tripos_mobile

import android.util.Log
import com.vantiv.triposmobilesdk.DeviceInteractionListener
import com.vantiv.triposmobilesdk.SaleRequestListener
import com.vantiv.triposmobilesdk.VTP
import com.vantiv.triposmobilesdk.VtpStatus
import com.vantiv.triposmobilesdk.enums.CardHolderPresentCode
import com.vantiv.triposmobilesdk.enums.GiftProgramType
import com.vantiv.triposmobilesdk.requests.SaleRequest
import com.vantiv.triposmobilesdk.responses.SaleResponse
import java.math.BigDecimal

/**
 * A minimal sale flow that mirrors the official sampleapp SaleFragment implementation.
 * Plug this into experiments without touching TriposMobilePlugin.kt.
 */
class SampleSaleRunner(
    private val vtp: VTP,
    private val callbacks: Callbacks
) : SaleRequestListener {

    companion object {
        private const val TAG = "SampleSaleRunner"
    }

    /** Kick off a sale with the same required fields as the sample app. */
    fun startSale(
        amount: BigDecimal = BigDecimal("1.31"),
        reference: String = "1234567890A",
        lane: String = "1",
        clerk: String = "123456",
        shiftId: String = "9876",
        ticketNumber: String = "5555"
    ) {
        if (!vtp.isInitialized) {
            callbacks.onError("VTP not initialized")
            return
        }

        // Status listener identical to sampleapp
        vtp.setStatusListener { status ->
            callbacks.onStatus(status)
            Log.i(TAG, "VtpStatus: ${status.name}")
        }

        val saleRequest = SaleRequest().apply {
            setTransactionAmount(amount)
            setLaneNumber(lane)
            setReferenceNumber(reference)
            setCardholderPresentCode(CardHolderPresentCode.Present)
            setClerkNumber(clerk)
            setShiftID(shiftId)
            setTicketNumber(ticketNumber)
            setGiftProgramType(GiftProgramType.Gift)
            setPinLessposConversionIndicator(false)
            setSurchargeFeeAmount(BigDecimal("1.00"))
        }

        try {
            vtp.processSaleRequest(saleRequest, this, buildDeviceListener())
        } catch (e: Exception) {
            Log.e(TAG, "processSaleRequest failed", e)
            callbacks.onError(e.message ?: "processSaleRequest failed")
        }
    }

    private fun buildDeviceListener(): DeviceInteractionListener = object : DeviceInteractionListener {
        override fun onAmountConfirmation(
            amountConfirmationType: com.vantiv.triposmobilesdk.enums.AmountConfirmationType?,
            amount: BigDecimal?,
            callback: DeviceInteractionListener.ConfirmAmountListener?
        ) {
            callbacks.onUiMessage("Confirm amount: $amount")
            callback?.confirmAmount(true)
        }

        override fun onChoiceSelections(
            choices: Array<out String>?,
            selectionType: com.vantiv.triposmobilesdk.enums.SelectionType?,
            callback: DeviceInteractionListener.SelectChoiceListener?
        ) {
            callback?.selectChoice(0)
        }

        override fun onNumericInput(
            numericInputType: com.vantiv.triposmobilesdk.enums.NumericInputType?,
            callback: DeviceInteractionListener.NumericInputListener?
        ) {
            callback?.enterNumericInput("0")
        }

        override fun onSelectApplication(
            applications: Array<out String>?,
            callback: DeviceInteractionListener.SelectChoiceListener?
        ) {
            callback?.selectChoice(0)
        }

        override fun onPromptUserForCard(
            prompt: String?,
            displayTextIdentifiers: com.vantiv.triposmobilesdk.enums.DisplayTextIdentifiers?
        ) {
            callbacks.onUiMessage(prompt ?: "Insert/Swipe/Tap Card")
        }

        override fun onDisplayText(
            text: String?,
            displayTextIdentifiers: com.vantiv.triposmobilesdk.enums.DisplayTextIdentifiers?
        ) {
            callbacks.onUiMessage(text ?: "")
        }

        override fun onRemoveCard() {
            callbacks.onUiMessage("Remove card")
        }

        override fun onCardRemoved() {
            callbacks.onUiMessage("Card removed")
        }

        override fun onWait(message: String?) {
            callbacks.onUiMessage(message ?: "Please wait...")
        }
    }

    // --- SaleRequestListener implementation ---
    override fun onSaleRequestCompleted(saleResponse: SaleResponse) {
        callbacks.onCompleted(saleResponse)
    }

    override fun onSaleRequestError(e: Exception) {
        callbacks.onError(e.message ?: "Sale error")
    }

    interface Callbacks {
        fun onStatus(status: VtpStatus)
        fun onUiMessage(msg: String)
        fun onCompleted(response: SaleResponse)
        fun onError(msg: String)
    }
}
