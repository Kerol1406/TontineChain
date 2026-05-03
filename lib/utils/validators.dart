/// Validateurs pour les formulaires
class Validators {
  /// Valider un email
  static String? validateEmail(String? value) {
    if (value == null || value.isEmpty) {
      return 'L\'email est obligatoire';
    }
    final emailRegex = RegExp(
      r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
    );
    if (!emailRegex.hasMatch(value)) {
      return 'Veuillez entrer un email valide';
    }
    return null;
  }

  /// Valider un téléphone
  static String? validatePhone(String? value) {
    if (value == null || value.isEmpty) {
      return 'Le téléphone est obligatoire';
    }
    if (value.length < 10) {
      return 'Le téléphone doit contenir au moins 10 chiffres';
    }
    return null;
  }

  /// Valider un nombre
  static String? validateAmount(String? value) {
    if (value == null || value.isEmpty) {
      return 'Le montant est obligatoire';
    }
    final amount = double.tryParse(value);
    if (amount == null || amount <= 0) {
      return 'Veuillez entrer un montant valide';
    }
    return null;
  }

  /// Valider un champ texte non vide
  static String? validateRequired(String? value) {
    if (value == null || value.isEmpty) {
      return 'Ce champ est obligatoire';
    }
    return null;
  }

  /// Valider une longueur minimale
  static String? validateMinLength(String? value, int minLength) {
    if (value == null || value.isEmpty) {
      return 'Ce champ est obligatoire';
    }
    if (value.length < minLength) {
      return 'Le texte doit contenir au moins $minLength caractères';
    }
    return null;
  }
}
