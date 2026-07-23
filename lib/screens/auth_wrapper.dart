class AuthWrapper extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
      stream: Supabase.instance.client.auth.onAuthStateChange,
      builder: (context, snapshot) {
        if (snapshot.data?.session == null) return LoginScreen();
        
        // Logika redirect berdasarkan peran
        return FutureBuilder<String?>(
          future: AuthService().getUserRole(),
          builder: (context, roleSnapshot) {
            if (roleSnapshot.hasData) {
              switch (roleSnapshot.data) {
                case 'admin': return AdminDashboard();
                case 'guru': return GuruDashboard();
                case 'siswa': return SiswaDashboard();
                default: return LoginScreen();
              }
            }
            return CircularProgressIndicator();
          },
        );
      },
    );
  }
}