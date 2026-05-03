/// Gestion centralisée des chemins des images
class AppImages {
  // Dossier des assets
  static const String _basePath = 'assets/images';

  // Logos
  static const String logoWithName = '$_basePath/Logo_TontineChaine_sans_nom.png';
  static const String logoSvg = '$_basePath/Logo_TontineChaine_sans_nom.svg';

  // Méthode pour accéder à des images génériques
  static String getImage(String imageName) => '$_basePath/$imageName';
}
