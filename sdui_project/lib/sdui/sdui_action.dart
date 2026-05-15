/// SDUI action — the tap payload attached to any node, or returned by the
/// server in response to a form submit.
///
/// Phase 5 additions: actions can be chained via `type: 'sequence'`,
/// gated by an `if` condition (evaluated against the singleton form data),
/// and wrapped in a confirmation dialog via `confirm`.
class SDUIAction {
  final String type;
  final String? url;
  final Map<String, dynamic>? payload;
  final String? successUrl;
  final String? successMessage;

  /// For `type: 'sequence'` — the list of inner actions to run in order.
  final List<SDUIAction>? actions;

  /// Optional gate: `{field: 'agree', equals: true}`. When set, the
  /// action is skipped unless `FormManager._formData[field] == equals`.
  final Map<String, dynamic>? condition;

  /// Optional confirmation: `{title, message, confirmLabel, cancelLabel,
  /// destructive}`. When set, an AlertDialog is shown and the action only
  /// runs if the user confirms.
  final Map<String, dynamic>? confirm;

  SDUIAction({
    required this.type,
    this.url,
    this.payload,
    this.successUrl,
    this.successMessage,
    this.actions,
    this.condition,
    this.confirm,
  });

  factory SDUIAction.fromJson(Map<String, dynamic> json) {
    final data = json['data'];
    final onSuccess = json['on_success'];
    final onSuccessMap = onSuccess is Map ? Map<String, dynamic>.from(onSuccess) : null;
    final rawActions = json['actions'];
    final cond = json['if'];
    final confirm = json['confirm'];
    return SDUIAction(
      type: json['type'] ?? 'unknown',
      url: json['url'],
      payload: data is Map ? Map<String, dynamic>.from(data) : null,
      successUrl: json['success_url'] ?? onSuccessMap?['navigate'] ?? onSuccessMap?['url'],
      successMessage: json['success_message'] ?? onSuccessMap?['message'],
      actions: rawActions is List
          ? rawActions
              .whereType<Map>()
              .map((a) => SDUIAction.fromJson(Map<String, dynamic>.from(a)))
              .toList()
          : null,
      condition: cond is Map ? Map<String, dynamic>.from(cond) : null,
      confirm: confirm is Map ? Map<String, dynamic>.from(confirm) : null,
    );
  }
}
