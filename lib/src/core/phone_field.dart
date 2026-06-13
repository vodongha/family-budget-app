import 'package:flutter/material.dart';
import 'package:phone_form_field/phone_form_field.dart';

/// An optional phone input with a country-code picker (built on
/// `phone_form_field`). Reports the **E.164** string (e.g. `+84912345678`) via
/// [onChanged], or `null` when the national number is empty — the backend is the
/// authority on validity, so an empty value simply means "no phone".
class AppPhoneField extends StatelessWidget {
  const AppPhoneField({
    super.key,
    required this.initialE164,
    required this.onChanged,
    required this.label,
    required this.invalidMessage,
  });

  /// Existing number in E.164 to pre-fill, or null/empty for a blank field.
  final String? initialE164;
  final void Function(String? e164) onChanged;
  final String label;
  final String invalidMessage;

  @override
  Widget build(BuildContext context) {
    PhoneNumber? initial;
    final String? raw = initialE164;
    if (raw != null && raw.isNotEmpty) {
      try {
        initial = PhoneNumber.parse(raw);
      } catch (_) {
        initial = null;
      }
    }
    return PhoneFormField(
      initialValue: initial ?? const PhoneNumber(isoCode: IsoCode.VN, nsn: ''),
      isCountrySelectionEnabled: true,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: const Icon(Icons.phone_outlined),
      ),
      validator: (PhoneNumber? p) {
        if (p == null || p.nsn.isEmpty) {
          return null; // optional
        }
        return p.isValid() ? null : invalidMessage;
      },
      onChanged: (PhoneNumber p) =>
          onChanged(p.nsn.isEmpty ? null : p.international),
    );
  }
}
