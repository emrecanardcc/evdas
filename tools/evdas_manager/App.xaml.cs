using System;
using System.Windows;
using System.Windows.Threading;

namespace EvdasManager;

/// <summary>
/// Interaction logic for App.xaml
/// </summary>
public partial class App : Application
{
    protected override void OnStartup(StartupEventArgs e)
    {
        base.OnStartup(e);

        AppDomain.CurrentDomain.UnhandledException += (s, args) =>
        {
            MessageBox.Show(
                "Evdaş Yönetim Paneli Başlatma Hatası:\n" + args.ExceptionObject,
                "Evdaş Manager Hatası",
                MessageBoxButton.OK,
                MessageBoxImage.Error);
        };

        DispatcherUnhandledException += (s, args) =>
        {
            MessageBox.Show(
                "Arayüz Hatası:\n" + args.Exception.Message + "\n\nDetay:\n" + args.Exception.StackTrace,
                "Evdaş Manager Hatası",
                MessageBoxButton.OK,
                MessageBoxImage.Error);
            args.Handled = true;
        };
    }
}
