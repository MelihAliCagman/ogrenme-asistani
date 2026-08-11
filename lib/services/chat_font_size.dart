enum ChatFontSize {
  small,
  medium,
  large;

  double get fontSize => switch (this) {
    ChatFontSize.small => 13,
    ChatFontSize.medium => 15,
    ChatFontSize.large => 18,
  };

  String get label => switch (this) {
    ChatFontSize.small => 'Küçük',
    ChatFontSize.medium => 'Orta',
    ChatFontSize.large => 'Büyük',
  };
}
