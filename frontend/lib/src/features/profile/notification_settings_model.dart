class NotificationSettingsModel {
  final bool isGlobalEnabled;
  final bool notifyOnMyPost;
  final bool notifyOnMyComment;

  NotificationSettingsModel({
    this.isGlobalEnabled = true,
    this.notifyOnMyPost = true,
    this.notifyOnMyComment = true,
  });

  Map<String, dynamic> toMap() {
    return {
      'isGlobalEnabled': isGlobalEnabled,
      'notifyOnMyPost': notifyOnMyPost,
      'notifyOnMyComment': notifyOnMyComment,
    };
  }

  factory NotificationSettingsModel.fromMap(Map<String, dynamic> map) {
    return NotificationSettingsModel(
      isGlobalEnabled: map['isGlobalEnabled'] ?? true,
      notifyOnMyPost: map['notifyOnMyPost'] ?? true,
      notifyOnMyComment: map['notifyOnMyComment'] ?? true,
    );
  }

  NotificationSettingsModel copyWith({
    bool? isGlobalEnabled,
    bool? notifyOnMyPost,
    bool? notifyOnMyComment,
  }) {
    return NotificationSettingsModel(
      isGlobalEnabled: isGlobalEnabled ?? this.isGlobalEnabled,
      notifyOnMyPost: notifyOnMyPost ?? this.notifyOnMyPost,
      notifyOnMyComment: notifyOnMyComment ?? this.notifyOnMyComment,
    );
  }
}
