/// OpenAlex topic-classification taxonomy (FR-13).
///
/// OpenAlex classifies works under Domain → Field → Subfield → Topic. The
/// filter panel exposes the top three tiers (Domain → Field → Subfield); the
/// deepest "Topic" tier is intentionally left out because the screen's keyword
/// search already covers free-text topic lookup.
///
/// Domains (4) and Fields (26) never change, so they are hard-coded here.
/// Subfields are fetched at runtime from the API (see
/// `OpenAlexService.getSubfields`).
///
/// Filters are built with the *short* id (the last path segment), never the
/// full URL — e.g. `primary_topic.field.id:17`. See [shortOpenAlexId].
library;

/// Extracts the short OpenAlex id (the last path segment) from an id value.
///
/// OpenAlex returns ids as full URLs:
///   "https://openalex.org/domains/1"      → "1"
///   "https://openalex.org/fields/17"      → "17"
///   "https://openalex.org/subfields/1702" → "1702"
///   "https://openalex.org/T10017"         → "T10017"
///
/// Filters expect exactly this short form. Hard-coded ids are already short and
/// pass through unchanged.
String shortOpenAlexId(String id) {
  final trimmed = id.trim();
  final slash = trimmed.lastIndexOf('/');
  return slash == -1 ? trimmed : trimmed.substring(slash + 1);
}

/// Tier 1: a research domain (4 total).
class Domain {
  const Domain({required this.id, required this.name});

  final String id;
  final String name;

  @override
  bool operator ==(Object other) =>
      other is Domain && other.id == id;

  @override
  int get hashCode => id.hashCode;
}

/// Tier 2: a research field (26 total), each owned by one [Domain].
class Field {
  const Field({required this.id, required this.name, required this.domainId});

  final String id;
  final String name;

  /// Short id of the parent [Domain].
  final String domainId;

  @override
  bool operator ==(Object other) => other is Field && other.id == id;

  @override
  int get hashCode => id.hashCode;
}

/// Tier 3: a subfield, loaded from `GET /subfields` and owned by one [Field].
class Subfield {
  const Subfield({
    required this.id,
    required this.displayName,
    required this.fieldId,
  });

  final String id;
  final String displayName;

  /// Short id of the parent [Field] (from `field.id`).
  final String fieldId;

  factory Subfield.fromJson(Map<String, dynamic> json) {
    final field = json['field'] as Map<String, dynamic>?;
    return Subfield(
      id: shortOpenAlexId((json['id'] ?? '').toString()),
      displayName: (json['display_name'] as String?) ?? 'Unknown subfield',
      fieldId: field == null
          ? ''
          : shortOpenAlexId((field['id'] ?? '').toString()),
    );
  }

  @override
  bool operator ==(Object other) => other is Subfield && other.id == id;

  @override
  int get hashCode => id.hashCode;
}

/// The current taxonomy selection (Domain → Field → Subfield), able to emit the
/// OpenAlex filter clause.
class TaxonomyFilter {
  const TaxonomyFilter({this.domain, this.field, this.subfield});

  final Domain? domain;
  final Field? field;
  final Subfield? subfield;

  /// Builds the single most-specific filter clause.
  ///
  /// The tiers are nested (a subfield already implies its field/domain), so only
  /// the deepest selected level is sent. Returns `null` when nothing is
  /// selected.
  String? toFilterClause() {
    if (subfield != null) return 'primary_topic.subfield.id:${subfield!.id}';
    if (field != null) return 'primary_topic.field.id:${field!.id}';
    if (domain != null) return 'primary_topic.domain.id:${domain!.id}';
    return null;
  }
}

/// Hard-coded tier-1/tier-2 reference data.
class Taxonomy {
  const Taxonomy._();

  /// The 4 OpenAlex domains.
  static const List<Domain> domains = [
    Domain(id: '1', name: 'Life Sciences'),
    Domain(id: '2', name: 'Social Sciences'),
    Domain(id: '3', name: 'Physical Sciences'),
    Domain(id: '4', name: 'Health Sciences'),
  ];

  /// The 26 OpenAlex fields, each tagged with its parent domain id.
  static const List<Field> fields = [
    Field(id: '11', name: 'Agricultural and Biological Sciences', domainId: '1'),
    Field(id: '12', name: 'Arts and Humanities', domainId: '2'),
    Field(
      id: '13',
      name: 'Biochemistry, Genetics and Molecular Biology',
      domainId: '1',
    ),
    Field(id: '14', name: 'Business, Management and Accounting', domainId: '2'),
    Field(id: '15', name: 'Chemical Engineering', domainId: '3'),
    Field(id: '16', name: 'Chemistry', domainId: '3'),
    Field(id: '17', name: 'Computer Science', domainId: '3'),
    Field(id: '18', name: 'Decision Sciences', domainId: '2'),
    Field(id: '19', name: 'Earth and Planetary Sciences', domainId: '3'),
    Field(id: '20', name: 'Economics, Econometrics and Finance', domainId: '2'),
    Field(id: '21', name: 'Energy', domainId: '3'),
    Field(id: '22', name: 'Engineering', domainId: '3'),
    Field(id: '23', name: 'Environmental Science', domainId: '3'),
    Field(id: '24', name: 'Immunology and Microbiology', domainId: '1'),
    Field(id: '25', name: 'Materials Science', domainId: '3'),
    Field(id: '26', name: 'Mathematics', domainId: '3'),
    Field(id: '27', name: 'Medicine', domainId: '4'),
    Field(id: '28', name: 'Neuroscience', domainId: '1'),
    Field(id: '29', name: 'Nursing', domainId: '4'),
    Field(
      id: '30',
      name: 'Pharmacology, Toxicology and Pharmaceutics',
      domainId: '1',
    ),
    Field(id: '31', name: 'Physics and Astronomy', domainId: '3'),
    Field(id: '32', name: 'Psychology', domainId: '2'),
    Field(id: '33', name: 'Social Sciences', domainId: '2'),
    Field(id: '34', name: 'Veterinary', domainId: '4'),
    Field(id: '35', name: 'Dentistry', domainId: '4'),
    Field(id: '36', name: 'Health Professions', domainId: '4'),
  ];

  /// Fields belonging to [domainId].
  static List<Field> fieldsForDomain(String domainId) =>
      fields.where((f) => f.domainId == domainId).toList();
}
