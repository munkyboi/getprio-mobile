import 'package:shadcn_flutter/shadcn_flutter.dart';

import '../app_theme.dart';
import '../auth/auth_repository.dart';
import 'security_repository.dart';

class DeleteAccountDialog extends StatefulWidget {
  const DeleteAccountDialog({
    super.key,
    required this.deleteAccount,
    required this.requiresPassword,
  });

  final Future<AccountDeletionReceipt> Function(String password) deleteAccount;
  final Future<bool> Function() requiresPassword;

  @override
  State<DeleteAccountDialog> createState() => _DeleteAccountDialogState();
}

class _DeleteAccountDialogState extends State<DeleteAccountDialog> {
  final _password = TextEditingController();
  bool _loadingRequirements = true;
  bool _requirementsFailed = false;
  bool _passwordRequired = true;
  bool _submitting = false;
  AccountDeletionReceipt? _receipt;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadRequirements();
  }

  @override
  void dispose() {
    _password.dispose();
    super.dispose();
  }

  Future<void> _loadRequirements() async {
    try {
      final required = await widget.requiresPassword();
      if (!mounted) return;
      setState(() {
        _passwordRequired = required;
        _loadingRequirements = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loadingRequirements = false;
        _requirementsFailed = true;
        _error = _messageFor(error);
      });
    }
  }

  Future<void> _submit() async {
    if (_submitting || _receipt != null || _loadingRequirements) return;
    if (_passwordRequired && _password.text.isEmpty) {
      setState(() => _error = 'Enter your current password to continue.');
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final receipt = await widget.deleteAccount(_password.text);
      if (!mounted) return;
      setState(() {
        _receipt = receipt;
        _submitting = false;
      });
      _password.clear();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _error = _messageFor(error);
      });
    }
  }

  String _messageFor(Object error) {
    if (error is ApiException) {
      return switch (error.code) {
        'ACCOUNT_DELETION_UNAVAILABLE' => 'Account deletion is temporarily unavailable. Please try again later.',
        'INVALID_PASSWORD' => 'That password is incorrect. Try again.',
        'PROVIDER_REAUTH_REQUIRED' => error.message,
        _ =>
          error.message.isEmpty
              ? 'We could not process account deletion. Please try again.'
              : error.message,
      };
    }
    return 'We could not process account deletion. Check your connection and try again.';
  }

  @override
  Widget build(BuildContext context) {
    final receipt = _receipt;
    final actionWidth = (MediaQuery.sizeOf(context).width - 64).clamp(
      240.0,
      380.0,
    );
    return PopScope(
      canPop: !_submitting && receipt == null,
      child: AlertDialog(
        key: Key(
          receipt == null ? 'delete-account-dialog' : 'delete-account-accepted',
        ),
        leading: const Icon(LucideIcons.trash2),
        title: Text(
          receipt == null ? 'Delete your account?' : 'Deletion requested',
        ),
        content: SizedBox(
          width: 380,
          child: SingleChildScrollView(
            child: receipt == null
                ? _buildConfirmationContent()
                : _buildSuccessContent(receipt),
          ),
        ),
        actions: [
          if (receipt == null)
            SizedBox(
              width: actionWidth,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  GetPrioActionButton.outline(
                    key: const Key('delete-account-cancel'),
                    onPressed: _submitting
                        ? null
                        : () => closeOverlay(context, false),
                    child: const Text('Keep my account'),
                  ),
                  const SizedBox(height: 8),
                  GetPrioActionButton.destructive(
                    key: const Key('delete-account-confirm'),
                    onPressed:
                        _submitting ||
                            _loadingRequirements ||
                            _requirementsFailed
                        ? null
                        : _submit,
                    child: Text(
                      _submitting
                          ? 'Submitting…'
                          : 'Request permanent deletion',
                    ),
                  ),
                ],
              ),
            )
          else
            SizedBox(
              width: actionWidth,
              child: GetPrioActionButton.primary(
                key: const Key('delete-account-done'),
                onPressed: () => closeOverlay(context, true),
                child: const Text('Done'),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildConfirmationContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text(
          'This permanently removes your account and personal data. Access is revoked immediately after your request is accepted.',
        ),
        const SizedBox(height: 12),
        const Text(
          'Waiting queue tickets will be cancelled. Records that must be retained by law may remain for that purpose. Payments and vendor services are not automatically refunded or cancelled.',
        ),
        const SizedBox(height: 16),
        if (_loadingRequirements)
          const Text('Loading verification requirements…')
        else if (!_passwordRequired)
          const Text(
            'To confirm, sign in again with your original Google, Facebook, or Apple account, then return here within five minutes.',
          )
        else ...[
          const Text('Current password'),
          const SizedBox(height: 8),
          TextField(
            key: const Key('delete-account-password'),
            controller: _password,
            obscureText: true,
            enabled: !_submitting,
            placeholder: const Text('Enter your current password'),
          ),
        ],
        if (_error != null) ...[
          const SizedBox(height: 12),
          Semantics(
            liveRegion: true,
            child: Text(
              _error!,
              style: TextStyle(color: GetPrioTheme.destructive),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildSuccessContent(AccountDeletionReceipt receipt) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text(
          'Your account access has been revoked. We will complete deletion by the date below and email you when it is finished.',
        ),
        const SizedBox(height: 12),
        Text(
          'Completion date: ${receipt.dueAt.toLocal().toString().split(' ').first}',
        ),
        const SizedBox(height: 8),
        SelectableText('Reference: ${receipt.requestId}'),
      ],
    );
  }
}
