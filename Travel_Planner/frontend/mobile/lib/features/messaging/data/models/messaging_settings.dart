enum InboundMessagePolicy { everyone, friendsOnly }

class MessagingSettings {
  final InboundMessagePolicy inboundPolicy;
  const MessagingSettings(this.inboundPolicy);

  factory MessagingSettings.fromJson(Map<String, dynamic> json) {
    final value = json['inboundPolicy']?.toString().toUpperCase();
    return MessagingSettings(switch (value) {
      'EVERYONE' => InboundMessagePolicy.everyone,
      'FRIENDS_ONLY' => InboundMessagePolicy.friendsOnly,
      // Older accounts may still have the removed NOBODY value persisted.
      'NOBODY' => InboundMessagePolicy.friendsOnly,
      _ => InboundMessagePolicy.everyone,
    });
  }

  String get apiValue => switch (inboundPolicy) {
    InboundMessagePolicy.everyone => 'EVERYONE',
    InboundMessagePolicy.friendsOnly => 'FRIENDS_ONLY',
  };
}
