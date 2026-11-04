typedef Json = Map<String, dynamic>;
Json object(dynamic value) =>
    value is Map ? Map<String, dynamic>.from(value) : {};
List<Json> objects(dynamic value) =>
    value is List ? value.map(object).toList() : [];
List<Json> pageItems(dynamic value) => value is List
    ? objects(value)
    : objects(object(value)['items'] ?? object(value)['content']);
double number(dynamic value) =>
    value is num ? value.toDouble() : double.tryParse('$value') ?? 0;
