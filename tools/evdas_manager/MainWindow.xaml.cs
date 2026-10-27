using System;
using System.Diagnostics;
using System.IO;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Input;
using System.Windows.Media;

namespace EvdasManager
{
    public partial class MainWindow : Window
    {
        private readonly MarkdownSyncService _syncService;
        private Point _dragStartPoint;
        private ItemModel? _draggedItem;
        private ListBox? _dragSourceList;

        public MainWindow()
        {
            InitializeComponent();
            _syncService = new MarkdownSyncService();
            TxtProjectPath.Text = _syncService.ProjectPath;

            BindLists();
            LoadData();
        }

        private void BindLists()
        {
            LstFikirHavuzu.ItemsSource = _syncService.FikirHavuzu;
            LstSecilenFikirler.ItemsSource = _syncService.SecilenFikirler;
            LstAktifUcretsiz.ItemsSource = _syncService.AktifUcretsiz;
            LstAktifPro.ItemsSource = _syncService.AktifPro;
            LstKaldirilacaklar.ItemsSource = _syncService.Kaldirilacaklar;
        }

        private void LoadData()
        {
            try
            {
                _syncService.LoadAll();
                TxtStatus.Text = $"Yuklendi ({DateTime.Now:HH:mm:ss})";
            }
            catch (Exception ex)
            {
                TxtStatus.Text = "Hata!";
                MessageBox.Show($"Dosyalar yuklenirken hata olustu:\n{ex.Message}", "Hata", MessageBoxButton.OK, MessageBoxImage.Error);
            }
        }

        #region Drag and Drop Handling

        private static T? FindAncestor<T>(DependencyObject? current) where T : DependencyObject
        {
            while (current != null)
            {
                if (current is T t) return t;
                current = VisualTreeHelper.GetParent(current);
            }
            return null;
        }

        private void ListBox_PreviewMouseLeftButtonDown(object sender, MouseButtonEventArgs e)
        {
            _dragStartPoint = e.GetPosition(null);
            if (sender is ListBox listBox)
            {
                var element = e.OriginalSource as DependencyObject;
                var itemContainer = FindAncestor<ListBoxItem>(element);
                if (itemContainer != null && itemContainer.DataContext is ItemModel item)
                {
                    _dragSourceList = listBox;
                    _draggedItem = item;
                    listBox.SelectedItem = item;
                }
                else
                {
                    _dragSourceList = null;
                    _draggedItem = null;
                }
            }
        }

        private void ListBox_MouseMove(object sender, MouseEventArgs e)
        {
            if (e.LeftButton == MouseButtonState.Pressed && _draggedItem != null && _dragSourceList != null)
            {
                Point currentPos = e.GetPosition(null);
                Vector diff = _dragStartPoint - currentPos;

                if (Math.Abs(diff.X) > SystemParameters.MinimumHorizontalDragDistance ||
                    Math.Abs(diff.Y) > SystemParameters.MinimumVerticalDragDistance)
                {
                    var data = new DataObject("EvdasItem", _draggedItem);
                    data.SetData("SourceList", _dragSourceList);
                    DragDrop.DoDragDrop(_dragSourceList, data, DragDropEffects.Move);
                    _draggedItem = null;
                    _dragSourceList = null;
                }
            }
        }

        private void ListBox_DragOver(object sender, DragEventArgs e)
        {
            if (e.Data.GetDataPresent("EvdasItem") || _draggedItem != null)
            {
                e.Effects = DragDropEffects.Move;
            }
            else
            {
                e.Effects = DragDropEffects.None;
            }
            e.Handled = true;
        }

        private void HandleDrop(ListBox targetList, DragEventArgs e)
        {
            ItemModel? item = null;
            ListBox? sourceList = null;

            if (e.Data.GetDataPresent("EvdasItem"))
            {
                item = e.Data.GetData("EvdasItem") as ItemModel;
            }
            if (e.Data.GetDataPresent("SourceList"))
            {
                sourceList = e.Data.GetData("SourceList") as ListBox;
            }

            item ??= _draggedItem;
            sourceList ??= _dragSourceList;

            if (item != null && sourceList != null && sourceList != targetList)
            {
                RemoveItemFromList(sourceList, item);
                AddItemToList(targetList, item);
                targetList.SelectedItem = item;
                TxtStatus.Text = $"Oge tasindi: [{item.Tag}]";
            }
        }

        private void LstFikirHavuzu_Drop(object sender, DragEventArgs e) => HandleDrop(LstFikirHavuzu, e);
        private void LstSecilenFikirler_Drop(object sender, DragEventArgs e) => HandleDrop(LstSecilenFikirler, e);
        private void LstAktifUcretsiz_Drop(object sender, DragEventArgs e) => HandleDrop(LstAktifUcretsiz, e);
        private void LstAktifPro_Drop(object sender, DragEventArgs e) => HandleDrop(LstAktifPro, e);
        private void LstKaldirilacaklar_Drop(object sender, DragEventArgs e) => HandleDrop(LstKaldirilacaklar, e);

        private void RemoveItemFromList(ListBox list, ItemModel item)
        {
            if (list == LstFikirHavuzu) _syncService.FikirHavuzu.Remove(item);
            else if (list == LstSecilenFikirler) _syncService.SecilenFikirler.Remove(item);
            else if (list == LstAktifUcretsiz) _syncService.AktifUcretsiz.Remove(item);
            else if (list == LstAktifPro) _syncService.AktifPro.Remove(item);
            else if (list == LstKaldirilacaklar) _syncService.Kaldirilacaklar.Remove(item);
        }

        private void AddItemToList(ListBox list, ItemModel item)
        {
            if (list == LstFikirHavuzu) _syncService.FikirHavuzu.Add(item);
            else if (list == LstSecilenFikirler) _syncService.SecilenFikirler.Add(item);
            else if (list == LstAktifUcretsiz) _syncService.AktifUcretsiz.Add(item);
            else if (list == LstAktifPro) _syncService.AktifPro.Add(item);
            else if (list == LstKaldirilacaklar) _syncService.Kaldirilacaklar.Add(item);
        }

        #endregion

        #region Move Action Buttons

        private void BtnMoveToSecilen_Click(object sender, RoutedEventArgs e)
        {
            if (LstFikirHavuzu.SelectedItem is ItemModel item)
            {
                _syncService.FikirHavuzu.Remove(item);
                _syncService.SecilenFikirler.Add(item);
                LstSecilenFikirler.SelectedItem = item;
                TxtStatus.Text = $"Secilenlere alindi: [{item.Tag}]";
            }
        }

        private void BtnMoveToHavuz_Click(object sender, RoutedEventArgs e)
        {
            if (LstSecilenFikirler.SelectedItem is ItemModel item)
            {
                _syncService.SecilenFikirler.Remove(item);
                _syncService.FikirHavuzu.Add(item);
                LstFikirHavuzu.SelectedItem = item;
                TxtStatus.Text = $"Havuza geri alindi: [{item.Tag}]";
            }
        }

        private void BtnMoveFreeToPro_Click(object sender, RoutedEventArgs e)
        {
            if (LstAktifUcretsiz.SelectedItem is ItemModel item)
            {
                _syncService.AktifUcretsiz.Remove(item);
                _syncService.AktifPro.Add(item);
                LstAktifPro.SelectedItem = item;
                TxtStatus.Text = $"Pro katmanina tasindi: [{item.Tag}]";
            }
        }

        private void BtnMoveFreeToKaldir_Click(object sender, RoutedEventArgs e)
        {
            if (LstAktifUcretsiz.SelectedItem is ItemModel item)
            {
                _syncService.AktifUcretsiz.Remove(item);
                _syncService.Kaldirilacaklar.Add(item);
                LstKaldirilacaklar.SelectedItem = item;
                TxtStatus.Text = $"Kaldirilacaklara tasindi: [{item.Tag}]";
            }
        }

        private void BtnMoveProToFree_Click(object sender, RoutedEventArgs e)
        {
            if (LstAktifPro.SelectedItem is ItemModel item)
            {
                _syncService.AktifPro.Remove(item);
                _syncService.AktifUcretsiz.Add(item);
                LstAktifUcretsiz.SelectedItem = item;
                TxtStatus.Text = $"Ucretsiz katmana alindi: [{item.Tag}]";
            }
        }

        private void BtnMoveProToKaldir_Click(object sender, RoutedEventArgs e)
        {
            if (LstAktifPro.SelectedItem is ItemModel item)
            {
                _syncService.AktifPro.Remove(item);
                _syncService.Kaldirilacaklar.Add(item);
                LstKaldirilacaklar.SelectedItem = item;
                TxtStatus.Text = $"Kaldirilacaklara tasindi: [{item.Tag}]";
            }
        }

        private void BtnMoveKaldirToFree_Click(object sender, RoutedEventArgs e)
        {
            if (LstKaldirilacaklar.SelectedItem is ItemModel item)
            {
                _syncService.Kaldirilacaklar.Remove(item);
                _syncService.AktifUcretsiz.Add(item);
                LstAktifUcretsiz.SelectedItem = item;
                TxtStatus.Text = $"Ucretsiz katmana iade edildi: [{item.Tag}]";
            }
        }

        private void BtnDeleteFikirHavuzu_Click(object sender, RoutedEventArgs e)
        {
            if (LstFikirHavuzu.SelectedItem is ItemModel item)
            {
                _syncService.FikirHavuzu.Remove(item);
                TxtStatus.Text = $"Silindi: [{item.Tag}]";
            }
        }

        private void BtnDeleteSecilen_Click(object sender, RoutedEventArgs e)
        {
            if (LstSecilenFikirler.SelectedItem is ItemModel item)
            {
                _syncService.SecilenFikirler.Remove(item);
                TxtStatus.Text = $"Silindi: [{item.Tag}]";
            }
        }

        private void BtnDeleteKaldir_Click(object sender, RoutedEventArgs e)
        {
            if (LstKaldirilacaklar.SelectedItem is ItemModel item)
            {
                _syncService.Kaldirilacaklar.Remove(item);
                TxtStatus.Text = $"Silindi: [{item.Tag}]";
            }
        }

        #endregion

        #region Add, Save, Reload, Autonomous Loop

        private void BtnAddNewItem_Click(object sender, RoutedEventArgs e)
        {
            string tag = TxtNewTag.Text.Trim();
            string desc = TxtNewDesc.Text.Trim();

            if (string.IsNullOrEmpty(tag))
            {
                MessageBox.Show("Lutfen bir etiket/baslik giriniz.", "Uyari", MessageBoxButton.OK, MessageBoxImage.Warning);
                return;
            }

            if (string.IsNullOrEmpty(desc))
            {
                MessageBox.Show("Lutfen bir aciklama giriniz.", "Uyari", MessageBoxButton.OK, MessageBoxImage.Warning);
                return;
            }

            var newItem = new ItemModel { Tag = tag.ToUpperInvariant(), Description = desc };

            int targetIndex = CmbTargetSection.SelectedIndex;
            switch (targetIndex)
            {
                case 0: _syncService.FikirHavuzu.Add(newItem); break;
                case 1: _syncService.SecilenFikirler.Add(newItem); break;
                case 2: _syncService.AktifUcretsiz.Add(newItem); break;
                case 3: _syncService.AktifPro.Add(newItem); break;
                case 4: _syncService.Kaldirilacaklar.Add(newItem); break;
            }

            TxtNewTag.Clear();
            TxtNewDesc.Clear();
            TxtStatus.Text = $"Yeni oge eklendi: [{newItem.Tag}]";
        }

        private void BtnSaveAll_Click(object sender, RoutedEventArgs e)
        {
            try
            {
                _syncService.SaveAll();
                TxtStatus.Text = $"Kaydedildi ({DateTime.Now:HH:mm:ss})";
                MessageBox.Show("fikirler.md ve ozellikler.md dosyalari basariyla guncellendi!", "Kaydedildi", MessageBoxButton.OK, MessageBoxImage.Information);
            }
            catch (Exception ex)
            {
                TxtStatus.Text = "Kayit Hatasi!";
                MessageBox.Show($"Kaydederken hata olustu:\n{ex.Message}", "Hata", MessageBoxButton.OK, MessageBoxImage.Error);
            }
        }

        private void BtnReload_Click(object sender, RoutedEventArgs e)
        {
            LoadData();
            MessageBox.Show("Dosyalar diskten yeniden okundu.", "Yenilendi", MessageBoxButton.OK, MessageBoxImage.Information);
        }

        private void BtnOpenFolder_Click(object sender, RoutedEventArgs e)
        {
            if (Directory.Exists(_syncService.ProjectPath))
            {
                Process.Start(new ProcessStartInfo
                {
                    FileName = _syncService.ProjectPath,
                    UseShellExecute = true
                });
            }
        }

        private void BtnAutonomousLoop_Click(object sender, RoutedEventArgs e)
        {
            try
            {
                // 1. Otonom Prompt Olustur ve Panoya Kopyala
                string prompt = _syncService.GenerateAutonomousPrompt();
                Clipboard.SetText(prompt);

                // 2. Proje kokune AUTONOMOUS_TRIGGER.flag yaz
                _syncService.TriggerAutonomousEvolution();

                TxtStatus.Text = "Otonom Evrim Komutu Panoya Kopyalandi!";

                MessageBox.Show(
                    "OTONOM EVRIM MOTORU KOMUTU PANOMA KOPYALANDI!\n\n" +
                    "AUTONOMOUS_TRIGGER.flag dosyasi guncellendi.\n" +
                    "Panodaki talimati Antigravity veya terminal ortaminda yapistirarak otonom evrim dongusunu baslatabilirsiniz.",
                    "Otonom Evrim Tetiklendi",
                    MessageBoxButton.OK,
                    MessageBoxImage.Information);
            }
            catch (Exception ex)
            {
                TxtStatus.Text = "Tetikleme Hatasi!";
                MessageBox.Show($"Otonom motor tetiklenirken hata olustu:\n{ex.Message}", "Hata", MessageBoxButton.OK, MessageBoxImage.Error);
            }
        }

        #endregion
    }
}