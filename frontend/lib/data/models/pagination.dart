class PaginationMetadata {
  final int total;
  final int limit;
  final int offset;

  PaginationMetadata({
    required this.total,
    required this.limit,
    required this.offset,
  });

  factory PaginationMetadata.fromJson(Map<String, dynamic> json) {
    return PaginationMetadata(
      total: json['total'] ?? 0,
      limit: json['limit'] ?? 20,
      offset: json['offset'] ?? 0,
    );
  }
}

class PaginatedResponse<T> {
  final List<T> items;
  final PaginationMetadata pagination;

  PaginatedResponse({
    required this.items,
    required this.pagination,
  });
}
