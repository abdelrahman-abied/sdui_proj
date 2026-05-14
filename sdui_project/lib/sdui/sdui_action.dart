class SDUIAction {
  final String type;
  final String? url;
  final Map<String, dynamic>? payload;
  final String? successUrl;
  final String? successMessage;

  SDUIAction({
    required this.type,
    this.url,
    this.payload,
    this.successUrl,
    this.successMessage,
  });

  factory SDUIAction.fromJson(Map<String, dynamic> json) {
    final data = json['data'];
    final onSuccess = json['on_success'];
    final onSuccessMap = onSuccess is Map ? Map<String, dynamic>.from(onSuccess) : null;
    return SDUIAction(
      type: json['type'] ?? 'unknown',
      url: json['url'],
      payload: data is Map ? Map<String, dynamic>.from(data) : null,
      successUrl: json['success_url'] ?? onSuccessMap?['navigate'] ?? onSuccessMap?['url'],
      successMessage: json['success_message'] ?? onSuccessMap?['message'],
    );
  }
}