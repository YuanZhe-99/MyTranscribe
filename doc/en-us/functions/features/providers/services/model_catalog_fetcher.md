# lib/features/providers/services/model_catalog_fetcher.dart

Application contracts and orchestration over shared AI/data services; storage paths, record identities and job history remain application-owned.

## Declarations

| Declaration | Purpose |
|---|---|
| `library;` | Ask a source which models it offers. |
| `const CatalogEntry({required this.modelName, this.displayName});` | Create a catalog entry. |
| `const CatalogException(this.message);` | Create a catalog exception. |
| `ModelCatalogFetcher({http.Client Function()? clientFactory})` | Create a fetcher. |
| `Future<List<CatalogEntry>> fetch(` | Ask a source what models it has. |
| `List<CatalogEntry> _parse(String body) {` | Read the model list out of a response body. |
| `ModelConfig modelFromCatalog(` | Turn a catalogue entry into a model record for one source. |
