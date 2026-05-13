/// Configuration de l'application
class AppConfig {
  // URL du backend (à configurer selon l'environnement)
  static const String backendUrl = 'http://localhost:8787'; // Développement local
  // static const String backendUrl = 'https://api.tontinechain.app'; // Production

  /// Initialiser la configuration au démarrage de l'app
  static void init() {
    print('[CONFIG] Backend URL: $backendUrl');
    // Optionnel: mettre à jour le BackendService avec l'URL
    // BackendService.instance.setBaseUrl(backendUrl);
  }
}
