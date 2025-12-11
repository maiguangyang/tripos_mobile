/// Request models for triPOS Mobile SDK transactions

import 'enums.dart';

/// Base class for transaction requests
abstract class TransactionRequest {
  /// Transaction amount in dollars
  final double transactionAmount;

  /// Lane number
  final String laneNumber;

  /// Reference number for tracking
  final String referenceNumber;

  /// Cardholder present status
  final CardHolderPresentCode cardholderPresentCode;

  /// Clerk number
  final String? clerkNumber;

  /// Shift ID
  final String? shiftId;

  /// Ticket number
  final String? ticketNumber;

  const TransactionRequest({
    required this.transactionAmount,
    this.laneNumber = '1',
    this.referenceNumber = '',
    this.cardholderPresentCode = CardHolderPresentCode.present,
    this.clerkNumber,
    this.shiftId,
    this.ticketNumber,
  });

  Map<String, dynamic> toMap();
}

/// Sale transaction request
class SaleRequest extends TransactionRequest {
  /// Convenience fee amount
  final double? convenienceFeeAmount;

  /// Sales tax amount
  final double? salesTaxAmount;

  /// Tip amount
  final double? tipAmount;

  /// Surcharge fee amount
  final double? surchargeFeeAmount;

  /// Gift program type
  final GiftProgramType? giftProgramType;

  /// Force keyed entry only
  final bool keyedOnly;

  /// PIN-less POS conversion indicator
  final bool pinLessPosConversionIndicator;

  const SaleRequest({
    required super.transactionAmount,
    super.laneNumber,
    super.referenceNumber,
    super.cardholderPresentCode,
    super.clerkNumber,
    super.shiftId,
    super.ticketNumber,
    this.convenienceFeeAmount,
    this.salesTaxAmount,
    this.tipAmount,
    this.surchargeFeeAmount,
    this.giftProgramType,
    this.keyedOnly = false,
    this.pinLessPosConversionIndicator = false,
  });

  @override
  Map<String, dynamic> toMap() => {
    'transactionAmount': transactionAmount,
    'laneNumber': laneNumber,
    'referenceNumber': referenceNumber,
    'cardholderPresentCode': cardholderPresentCode.name,
    'clerkNumber': clerkNumber,
    'shiftId': shiftId,
    'ticketNumber': ticketNumber,
    'convenienceFeeAmount': convenienceFeeAmount,
    'salesTaxAmount': salesTaxAmount,
    'tipAmount': tipAmount,
    'surchargeFeeAmount': surchargeFeeAmount,
    'giftProgramType': giftProgramType?.name,
    'keyedOnly': keyedOnly,
    'pinLessPosConversionIndicator': pinLessPosConversionIndicator,
  };
}

/// Refund transaction request
class RefundRequest extends TransactionRequest {
  /// Convenience fee amount
  final double? convenienceFeeAmount;

  /// Sales tax amount
  final double? salesTaxAmount;

  /// Gift program type
  final GiftProgramType? giftProgramType;

  /// PIN-less POS conversion indicator
  final bool pinLessPosConversionIndicator;

  const RefundRequest({
    required super.transactionAmount,
    super.laneNumber,
    super.referenceNumber,
    super.cardholderPresentCode,
    super.clerkNumber,
    super.shiftId,
    super.ticketNumber,
    this.convenienceFeeAmount,
    this.salesTaxAmount,
    this.giftProgramType,
    this.pinLessPosConversionIndicator = false,
  });

  @override
  Map<String, dynamic> toMap() => {
    'transactionAmount': transactionAmount,
    'laneNumber': laneNumber,
    'referenceNumber': referenceNumber,
    'cardholderPresentCode': cardholderPresentCode.name,
    'clerkNumber': clerkNumber,
    'shiftId': shiftId,
    'ticketNumber': ticketNumber,
    'convenienceFeeAmount': convenienceFeeAmount,
    'salesTaxAmount': salesTaxAmount,
    'giftProgramType': giftProgramType?.name,
    'pinLessPosConversionIndicator': pinLessPosConversionIndicator,
  };
}

/// Void transaction request
class VoidRequest {
  /// Transaction ID from original transaction
  final String transactionId;

  /// Transaction amount
  final double transactionAmount;

  /// Lane number
  final String laneNumber;

  /// Reference number
  final String referenceNumber;

  /// Market code
  final MarketCode marketCode;

  /// Clerk number
  final String? clerkNumber;

  /// Shift ID
  final String? shiftId;

  /// Ticket number
  final String? ticketNumber;

  /// Cardholder present status
  final CardHolderPresentCode cardholderPresentCode;

  /// PIN-less POS conversion indicator
  final bool pinLessPosConversionIndicator;

  const VoidRequest({
    required this.transactionId,
    required this.transactionAmount,
    this.laneNumber = '1',
    this.referenceNumber = '',
    this.marketCode = MarketCode.retail,
    this.clerkNumber,
    this.shiftId,
    this.ticketNumber,
    this.cardholderPresentCode = CardHolderPresentCode.present,
    this.pinLessPosConversionIndicator = false,
  });

  Map<String, dynamic> toMap() => {
    'transactionId': transactionId,
    'transactionAmount': transactionAmount,
    'laneNumber': laneNumber,
    'referenceNumber': referenceNumber,
    'marketCode': marketCode.name,
    'clerkNumber': clerkNumber,
    'shiftId': shiftId,
    'ticketNumber': ticketNumber,
    'cardholderPresentCode': cardholderPresentCode.name,
    'pinLessPosConversionIndicator': pinLessPosConversionIndicator,
  };
}

/// Linked refund request (uses original transaction ID, no card required)
class LinkedRefundRequest {
  /// Transaction ID from original sale transaction
  final String transactionId;

  /// Refund amount (can be partial or full)
  final double transactionAmount;

  /// Lane number
  final String laneNumber;

  /// Reference number for tracking
  final String referenceNumber;

  /// Clerk number
  final String? clerkNumber;

  /// Shift ID
  final String? shiftId;

  const LinkedRefundRequest({
    required this.transactionId,
    required this.transactionAmount,
    this.laneNumber = '1',
    this.referenceNumber = '',
    this.clerkNumber,
    this.shiftId,
  });

  Map<String, dynamic> toMap() => {
    'transactionId': transactionId,
    'transactionAmount': transactionAmount,
    'laneNumber': laneNumber,
    'referenceNumber': referenceNumber,
    'clerkNumber': clerkNumber,
    'shiftId': shiftId,
  };
}

/// Authorization request
class AuthorizationRequest extends TransactionRequest {
  /// Convenience fee amount
  final double? convenienceFeeAmount;

  /// Sales tax amount
  final double? salesTaxAmount;

  /// Gift program type
  final GiftProgramType? giftProgramType;

  /// Force keyed entry only
  final bool keyedOnly;

  /// PIN-less POS conversion indicator
  final bool pinLessPosConversionIndicator;

  const AuthorizationRequest({
    required super.transactionAmount,
    super.laneNumber,
    super.referenceNumber,
    super.cardholderPresentCode,
    super.clerkNumber,
    super.shiftId,
    super.ticketNumber,
    this.convenienceFeeAmount,
    this.salesTaxAmount,
    this.giftProgramType,
    this.keyedOnly = false,
    this.pinLessPosConversionIndicator = false,
  });

  @override
  Map<String, dynamic> toMap() => {
    'transactionAmount': transactionAmount,
    'laneNumber': laneNumber,
    'referenceNumber': referenceNumber,
    'cardholderPresentCode': cardholderPresentCode.name,
    'clerkNumber': clerkNumber,
    'shiftId': shiftId,
    'ticketNumber': ticketNumber,
    'convenienceFeeAmount': convenienceFeeAmount,
    'salesTaxAmount': salesTaxAmount,
    'giftProgramType': giftProgramType?.name,
    'keyedOnly': keyedOnly,
    'pinLessPosConversionIndicator': pinLessPosConversionIndicator,
  };
}

/// Authorization completion request
class AuthorizationCompletionRequest {
  /// Transaction ID from authorization
  final String transactionId;

  /// Transaction amount
  final double transactionAmount;

  /// Lane number
  final String laneNumber;

  /// Reference number
  final String referenceNumber;

  /// Clerk number
  final String? clerkNumber;

  /// Shift ID
  final String? shiftId;

  /// Ticket number
  final String? ticketNumber;

  const AuthorizationCompletionRequest({
    required this.transactionId,
    required this.transactionAmount,
    this.laneNumber = '1',
    this.referenceNumber = '',
    this.clerkNumber,
    this.shiftId,
    this.ticketNumber,
  });

  Map<String, dynamic> toMap() => {
    'transactionId': transactionId,
    'transactionAmount': transactionAmount,
    'laneNumber': laneNumber,
    'referenceNumber': referenceNumber,
    'clerkNumber': clerkNumber,
    'shiftId': shiftId,
    'ticketNumber': ticketNumber,
  };
}
