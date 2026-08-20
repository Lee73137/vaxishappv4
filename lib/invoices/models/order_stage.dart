import 'package:flutter/material.dart';

/// The canonical lifecycle a `vaxi_clinicbooking` order moves through, from
/// being placed to going out for delivery. Matches the real values in the
/// `vaxi_status` table (case-insensitively — see reachedStageCount below),
/// not just names that read naturally; e.g. it's "WAITING FOR DELIVERY" and
/// "FOR PREPARATION" in the actual data, not "AWAITING..."/"PREPARATION".
/// DELIVERED is the terminal state beyond this list — reaching it marks
/// every stage below as complete. Exception statuses that don't belong to
/// the normal happy path (Void, Out of Stocks, Returned, Replacement,
/// Cancelled, Double Booking, To Davao) aren't part of this sequence.
/// ON-HOLD, FOR DISCOUNTING, FOR VERIFICATION, and DR PRINTING aren't shown
/// as their own stages either — see [_normalizeStatus].
const List<String> kOrderStages = [
  'INITIAL',
  'FOR CHECKING',
  'FOR PREPARATION',
  'WAITING FOR DELIVERY',
  'OUT FOR DELIVERY',
];

const String kDeliveredStatus = 'DELIVERED';

/// Display label for a stage — kept separate from the matching key in
/// [kOrderStages] itself, since the real `vaxi_status` value is still
/// "Waiting for Delivery"; only how it reads on screen changes.
String displayLabelForOrderStage(String stage) {
  return stage == 'WAITING FOR DELIVERY' ? 'AWAITING DELIVERY SCHEDULE' : stage;
}

IconData iconForOrderStage(String stage) {
  switch (stage) {
    case 'INITIAL':
      return Icons.receipt_long_rounded;
    case 'FOR CHECKING':
      return Icons.fact_check_outlined;
    case 'FOR PREPARATION':
      return Icons.inventory_2_outlined;
    case 'WAITING FOR DELIVERY':
      return Icons.inventory_rounded;
    case 'OUT FOR DELIVERY':
      return Icons.local_shipping_outlined;
    default:
      return Icons.circle_outlined;
  }
}

/// Statuses that don't get their own visible stage collapse into the
/// nearest real stage instead of a dead end that shows nothing highlighted:
/// ON-HOLD is a pause before checking even starts, so it counts as still
/// being at FOR CHECKING; FOR DISCOUNTING/FOR VERIFICATION/DR PRINTING are
/// the internal admin steps between preparation and delivery, so they all
/// count as still being at FOR PREPARATION.
String _normalizeStatus(String rawStatus) {
  final normalized = rawStatus.trim().toUpperCase();
  switch (normalized) {
    case 'ON-HOLD':
      return 'FOR CHECKING';
    case 'FOR DISCOUNTING':
    case 'FOR VERIFICATION':
    case 'DR PRINTING':
      return 'FOR PREPARATION';
    default:
      return normalized;
  }
}

/// Number of [kOrderStages] reached given a raw status string (0 if it
/// doesn't match a known stage yet). Returns `kOrderStages.length` (i.e.
/// every stage reached) once the status is DELIVERED.
int reachedStageCount(String rawStatus) {
  final normalized = _normalizeStatus(rawStatus);
  if (normalized == kDeliveredStatus) return kOrderStages.length;
  final index = kOrderStages.indexOf(normalized);
  return index == -1 ? 0 : index + 1;
}

bool isDeliveredStatus(String rawStatus) =>
    rawStatus.trim().toUpperCase() == kDeliveredStatus;
