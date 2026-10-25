import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/legal_texts.dart';
import '../../core/services/supabase_service.dart';
import '../widgets/legal_document_modal.dart';
import '../widgets/pattern_background.dart';
import 'home_screen.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Giriş Formu
  final _loginEmailController = TextEditingController();
  final _loginPasswordController = TextEditingController();

  // Kayıt Formu
  final _registerNameController = TextEditingController();
  final _registerEmailController = TextEditingController();
  final _registerPasswordController = TextEditingController();
  final _registerIbanController = TextEditingController();
  bool _acceptTerms = false;

  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _loginEmailController.dispose();
    _loginPasswordController.dispose();
    _registerNameController.dispose();
    _registerEmailController.dispose();
    _registerPasswordController.dispose();
    _registerIbanController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    final email = _loginEmailController.text.trim();
    final password = _loginPasswordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      setState(() => _errorMessage = 'Lütfen e-posta ve şifrenizi girin.');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await SupabaseService.signIn(email: email, password: password);
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const HomeScreen()),
        );
      }
    } catch (e) {
      setState(() {
        final err = e.toString().toLowerCase();
        if (err.contains('invalid login credentials') ||
            err.contains('invalid_credentials')) {
          _errorMessage = 'Giriş başarısız: E-posta adresi veya şifre hatalı.';
        } else if (err.contains('email not confirmed')) {
          _errorMessage =
              'Lütfen e-posta adresinize gelen onay bağlantısına tıklayın.';
        } else {
          _errorMessage = 'Giriş yapılamadı: İnternet bağlantınızı kontrol edin.';
        }
      });
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleRegister() async {
    final name = _registerNameController.text.trim();
    final email = _registerEmailController.text.trim();
    final password = _registerPasswordController.text.trim();
    final iban = _registerIbanController.text.trim();

    if (name.isEmpty || email.isEmpty || password.isEmpty) {
      setState(() => _errorMessage = 'İsim, e-posta ve şifre zorunludur.');
      return;
    }

    if (password.length < 6) {
      setState(() => _errorMessage = 'Şifre en az 6 karakter olmalıdır.');
      return;
    }

    if (!_acceptTerms) {
      setState(() =>
          _errorMessage = 'Lütfen Kullanıcı Sözleşmesi ve Gizlilik Politikasını onaylayın.');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final res = await SupabaseService.signUp(
        email: email,
        password: password,
        fullName: name,
        iban: iban.isNotEmpty ? iban : null,
      );

      if (mounted) {
        if (res.session != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Hesabınız oluşturuldu! Evdaş\'a hoş geldiniz.'),
              backgroundColor: AppColors.positive,
            ),
          );
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const HomeScreen()),
          );
        } else {
          // E-posta onayı gerekiyorsa
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                  'Kayıt başarılı! Lütfen e-postanıza gelen doğrulama bağlantısına tıklayın.'),
              backgroundColor: AppColors.primary,
              duration: Duration(seconds: 4),
            ),
          );
          _tabController.animateTo(0);
        }
      }
    } catch (e) {
      setState(() {
        final err = e.toString().toLowerCase();
        if (err.contains('already registered') || err.contains('unique')) {
          _errorMessage = 'Bu e-posta adresiyle kayıtlı bir hesap zaten var.';
        } else {
          _errorMessage =
              'Kayıt işlemi başarısız: Lütfen bilgilerinizi kontrol edin.';
        }
      });
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showForgotPasswordDialog() {
    final resetEmailController =
        TextEditingController(text: _loginEmailController.text.trim());
    bool isSubmitting = false;

    showDialog(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Şifremi Unuttum'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Kayıtlı e-posta adresinizi girin. Size şifre sıfırlama bağlantısı göndereceğiz.',
                  style: TextStyle(fontSize: 13),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: resetEmailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: InputDecoration(
                    labelText: 'E-posta',
                    prefixIcon: const Icon(Icons.email_outlined),
                    border:
                        OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  autofocus: true,
                ),
              ],
            ),
          ),
          actionsOverflowDirection: VerticalDirection.down,
          actionsOverflowButtonSpacing: 8,
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx),
              style: TextButton.styleFrom(minimumSize: const Size(0, 48)),
              child: const Text('İptal'),
            ),
            ElevatedButton(
              onPressed: isSubmitting
                  ? null
                  : () async {
                      final email = resetEmailController.text.trim();
                      if (email.isEmpty) return;
                      setDialogState(() => isSubmitting = true);
                      try {
                        await SupabaseService.resetPassword(email);
                        if (dialogCtx.mounted) {
                          Navigator.pop(dialogCtx);
                        }
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                  'Şifre sıfırlama bağlantısı e-posta adresinize gönderildi!'),
                              backgroundColor: AppColors.positive,
                            ),
                          );
                        }
                      } catch (e) {
                        setDialogState(() => isSubmitting = false);
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                  'Sıfırlama e-postası gönderilemedi. Lütfen adresi kontrol edin.'),
                              backgroundColor: AppColors.negative,
                            ),
                          );
                        }
                      }
                    },
              style: ElevatedButton.styleFrom(minimumSize: const Size(0, 48)),
              child: isSubmitting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Bağlantı Gönder'),
            ),
          ],
        ),
      ),
    );
  }

  void _showTermsDialog() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.grey.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const Text(
                'Yasal Sözleşmeler ve Bildirimler',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.description_outlined,
                      color: AppColors.primary, size: 20),
                ),
                title: const Text(
                  'Kullanım Koşulları ve Lisans (EULA)',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                ),
                trailing: const Icon(Icons.chevron_right, size: 20),
                onTap: () {
                  Navigator.pop(ctx);
                  LegalDocumentModal.show(
                    context,
                    title: LegalTexts.termsOfServiceTitle,
                    content: LegalTexts.termsOfService,
                  );
                },
              ),
              const Divider(height: 12),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.privacy_tip_outlined,
                      color: AppColors.primary, size: 20),
                ),
                title: const Text(
                  'Gizlilik Politikası ve KVKK Aydınlatma Metni',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                ),
                trailing: const Icon(Icons.chevron_right, size: 20),
                onTap: () {
                  Navigator.pop(ctx);
                  LegalDocumentModal.show(
                    context,
                    title: LegalTexts.privacyPolicyTitle,
                    content: LegalTexts.privacyPolicy,
                  );
                },
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PatternBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Logo & Başlık
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(22),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withValues(alpha: 0.35),
                          blurRadius: 18,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.account_balance_wallet_rounded,
                      color: Colors.white,
                      size: 38,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Evdaş',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Ortak Masraf & Harcama Yönetimi',
                    style: TextStyle(
                      fontSize: 14,
                      color: Theme.of(context).textTheme.bodyMedium?.color,
                    ),
                  ),
                  const SizedBox(height: 28),

                  // Tab Bar
                  Container(
                    decoration: BoxDecoration(
                      color: Theme.of(context).cardTheme.color,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Theme.of(context).colorScheme.outline,
                      ),
                    ),
                    padding: const EdgeInsets.all(4),
                    child: TabBar(
                      controller: _tabController,
                      indicator: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      indicatorSize: TabBarIndicatorSize.tab,
                      labelColor: Colors.white,
                      unselectedLabelColor:
                          Theme.of(context).textTheme.bodyMedium?.color,
                      labelStyle: const TextStyle(fontWeight: FontWeight.w700),
                      tabs: const [
                        Tab(text: 'Giriş Yap'),
                        Tab(text: 'Kayıt Ol'),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Hata Mesajı
                  if (_errorMessage != null)
                    Container(
                      padding: const EdgeInsets.all(12),
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: AppColors.negative.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: AppColors.negative.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.error_outline,
                              color: AppColors.negative, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _errorMessage!,
                              style: const TextStyle(
                                color: AppColors.negative,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                  // Tab Görünümleri
                  SizedBox(
                    height: 420,
                    child: TabBarView(
                      controller: _tabController,
                      children: [
                        // 1. GİRİŞ YAP
                        _buildLoginForm(),

                        // 2. KAYIT OL
                        _buildRegisterForm(),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLoginForm() {
    return SingleChildScrollView(
      physics: const ClampingScrollPhysics(),
      child: Column(
        children: [
          TextField(
            controller: _loginEmailController,
            keyboardType: TextInputType.emailAddress,
            decoration: InputDecoration(
              labelText: 'E-posta',
              prefixIcon: const Icon(Icons.email_outlined),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _loginPasswordController,
            obscureText: true,
            decoration: InputDecoration(
              labelText: 'Şifre',
              prefixIcon: const Icon(Icons.lock_outline),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: _showForgotPasswordDialog,
              child: const Text(
                'Şifremi Unuttum?',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              ),
            ),
          ),
          const SizedBox(height: 8),
          ElevatedButton(
            onPressed: _isLoading ? null : _handleLogin,
            style: ElevatedButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            child: _isLoading
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2.5,
                    ),
                  )
                : const Text('Giriş Yap'),
          ),
        ],
      ),
    );
  }

  Widget _buildRegisterForm() {
    return SingleChildScrollView(
      child: Column(
        children: [
          TextField(
            controller: _registerNameController,
            textCapitalization: TextCapitalization.words,
            decoration: InputDecoration(
              labelText: 'İsim Soyisim',
              prefixIcon: const Icon(Icons.person_outline),
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              isDense: true,
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _registerEmailController,
            keyboardType: TextInputType.emailAddress,
            decoration: InputDecoration(
              labelText: 'E-posta',
              prefixIcon: const Icon(Icons.email_outlined),
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              isDense: true,
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _registerPasswordController,
            obscureText: true,
            decoration: InputDecoration(
              labelText: 'Şifre (Min. 6 Karakter)',
              prefixIcon: const Icon(Icons.lock_outline),
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              isDense: true,
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _registerIbanController,
            decoration: InputDecoration(
              labelText: 'IBAN (İsteğe bağlı)',
              hintText: 'TR...',
              prefixIcon: const Icon(Icons.credit_card_outlined),
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              isDense: true,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              SizedBox(
                height: 24,
                width: 24,
                child: Checkbox(
                  value: _acceptTerms,
                  onChanged: (val) {
                    setState(() => _acceptTerms = val ?? false);
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: GestureDetector(
                  onTap: _showTermsDialog,
                  child: Text.rich(
                    TextSpan(
                      text: 'Kullanım Koşulları ve Gizlilik',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary,
                        decoration: TextDecoration.underline,
                      ),
                      children: [
                        TextSpan(
                          text: ' metnini okudum, kabul ediyorum.',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.color,
                            decoration: TextDecoration.none,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: _isLoading ? null : _handleRegister,
            style: ElevatedButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            child: _isLoading
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2.5,
                    ),
                  )
                : const Text('Hesap Oluştur'),
          ),
        ],
      ),
    );
  }
}
