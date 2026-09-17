/// Returns the versioned path used by first-party mobile API requests.
///
/// Callers keep endpoint paths grouped by their existing resource namespace,
/// while the transport owns the API version boundary. This keeps the v1
/// migration consistent for authenticated requests, uploads, and SSE streams.
String versionedApiPath(String path) {
  if (path == '/api' || path == '/api/v1' || path.startsWith('/api/v1/')) {
    return path;
  }
  if (path.startsWith('/api/')) return path.replaceFirst('/api/', '/api/v1/');
  return path;
}
