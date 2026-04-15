class VocabItem {
  final String word;
  final String translation;
  final String context;
  final String status;
  final int step;
  final String? nextReview;
  final String? remoteId;
  final bool deleted;
  final bool pending;
  final String? createdAt;
  final String? updatedAt;
  final String? localKey;

  VocabItem({
    required this.word,
    required this.translation,
    required this.context,
    required this.status,
    required this.step,
    this.nextReview,
    this.remoteId,
    required this.deleted,
    required this.pending,
    this.createdAt,
    this.updatedAt,
    this.localKey,
  });

  factory VocabItem.fromMap(Map<String, dynamic> map) {
    return VocabItem(
      word: map['word'] ?? '',
      translation: map['translation'] ?? '',
      context: map['context'] ?? '',
      status: map['status'] ?? 'learning',
      step: map['step'] ?? 0,
      nextReview: map['nextReview'],
      remoteId: map['remoteId'],
      deleted: map['deleted'] ?? false,
      pending: map['pending'] ?? false,
      createdAt: map['createdAt'],
      updatedAt: map['updatedAt'],
      localKey: map['__localKey'] ?? map['localKey'],
    );
  }
}
