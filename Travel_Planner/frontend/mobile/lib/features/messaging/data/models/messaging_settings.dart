enum InboundMessagePolicy { everyone, friendsOnly, nobody }

class MessagingSettings {
  final InboundMessagePolicy inboundPolicy;
  const MessagingSettings(this.inboundPolicy);

  factory MessagingSettings.fromJson(Map<String, dynamic> json) {
    final value = json['inboundPolicy']?.toString().toUpperCase();
    return MessagingSettings(switch (value) {
      'EVERYONE' => InboundMessagePolicy.everyone,
      'NOBODY' => InboundMessagePolicy.nobody,
      _ => InboundMessagePolicy.friendsOnly,
    });
  }

  String get apiValue => switch (inboundPolicy) {
    InboundMessagePolicy.everyone => 'EVERYONE',
    InboundMessagePolicy.friendsOnly => 'FRIENDS_ONLY',
    InboundMessagePolicy.nobody => 'NOBODY',
  };
}
