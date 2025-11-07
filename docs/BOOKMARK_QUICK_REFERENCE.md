# Bookmark - Quick Reference Guide

Hızlı dizin işaretleme ve gezinme sistemi.

## 🚀 Hızlı Başlangıç

### Temel İşlemler

```bash
bookmark .                          # Mevcut dizini kaydet (numaralı)
bookmark 1                          # 1 numaralı bookmark'a git
bookmark . -n proje                 # İsimle kaydet
bookmark proje                      # İsimli bookmark'a git
bookmark list                       # Tümünü listele
bookmark list -i                    # İnteraktif menü (ok tuşları)
```

## 📋 Kategori Bazlı Kullanım

### Kategorilendirme

```bash
bookmark . -n mlh in tools          # Kategoriyle kaydet
bookmark . -n api in projects/java  # Alt kategori
bookmark list projects              # Kategori filtrele
bookmark mv mlh to utils            # Kategoriye taşı
```

### Arama & Düzenleme

```bash
bookmark find java                  # Ara
bookmark edit mlh                   # Düzenle (isim/path/kategori)
bookmark rm proje                   # Sil
```

### Liste İşlemleri

```bash
bookmark list 5                     # Son 5 numaralıyı göster
bookmark clear                      # Numaralıları temizle
```

## ⌨️ İnteraktif Mod (bookmark list -i)

### Navigasyon

```
↑/↓ veya j/k                       # Gezinme
Enter                               # Bookmark'a git
e                                   # Düzenle
d                                   # Sil
h                                   # Yardım
q                                   # Çık
```

## 💡 İpuçları

### Hızlı Workflow

1. Projelere kategori ver: `bookmark . -n X in projects`
2. İnteraktif menüyü kullan: `bookmark list -i`
3. Ok tuşlarıyla seç ve Enter'a bas

### Organizasyon

- **Hiyerarşik kategoriler**: `aaa/bbb/ccc` şeklinde alt kategoriler
- **İsim çakışması önleme**: Sistem komutları otomatik engellenmiş
- **Otomatik yol validasyonu**: ⚠ silinen path'ler işaretlenir

## 📦 Özellikler

- **Stack-based numaralı bookmark'lar**: Max 10, LIFO (son eklenen #1 olur)
- **İsimli bookmark'lar**: Sınırsız, kalıcı
- **Hiyerarşik kategoriler**: Çok seviyeli organizasyon
- **Fuzzy search**: `bookmark find` ile akıllı arama
- **JSON storage**: `~/.mylinuxhelper/bookmarks.json`
- **Path validation**: Silinmiş dizinler için uyarı

## 📊 Komut Referansı (Alfabetik)

| Komut                           | Açıklama                | Örnek                       |
|---------------------------------|-------------------------|-----------------------------|
| `bookmark .`                    | Mevcut dizini kaydet    | `bookmark .`                |
| `bookmark . -n <name>`          | İsimle kaydet           | `bookmark . -n myapp`       |
| `bookmark . -n <name> in <cat>` | Kategoriyle kaydet      | `bookmark . -n api in java` |
| `bookmark <number>`             | Numaralı bookmark'a git | `bookmark 1`                |
| `bookmark <name>`               | İsimli bookmark'a git   | `bookmark myapp`            |
| `bookmark clear`                | Numaralıları temizle    | `bookmark clear`            |
| `bookmark edit <name>`          | Düzenle                 | `bookmark edit myapp`       |
| `bookmark find <pattern>`       | Ara                     | `bookmark find shop`        |
| `bookmark list`                 | Tümünü listele          | `bookmark list`             |
| `bookmark list -i`              | İnteraktif menü         | `bookmark list -i`          |
| `bookmark list <category>`      | Kategori filtrele       | `bookmark list java`        |
| `bookmark list <N>`             | Son N numaralı          | `bookmark list 5`           |
| `bookmark mv <name> to <cat>`   | Kategoriye taşı         | `bookmark mv api to tools`  |
| `bookmark rm <name\|number>`    | Sil                     | `bookmark rm oldapp`        |
| `bookmark --help`               | Yardım                  | `bookmark --help`           |

## 🎯 Kullanım Senaryoları

### Senaryo 1: Proje Dizinleri Arasında Hızlı Geçiş

```bash
# Projeleri kategorize et
bookmark . -n frontend in work/projects
bookmark . -n backend in work/projects
bookmark . -n docs in work/projects

# İnteraktif menüyle git
bookmark list -i
```

### Senaryo 2: Geçici Dizinleri Hatırlama

```bash
# Hızlıca kaydet
bookmark .                          # #1 olarak kaydedilir

cd /etc/nginx/sites-available
# ... işlemleri yap ...

# Geri dön
bookmark 1
```

### Senaryo 3: Kategorize Edilmiş Workspace

```bash
# Kategorilere göre organize et
bookmark . -n api in java/backend
bookmark . -n web in js/frontend
bookmark . -n mobile in kotlin/android

# Kategori filtrele
bookmark list java                  # Sadece java kategorisi
bookmark find backend               # Backend içeren tümü
```

### Senaryo 4: Hızlı Arama ve Gezinme

```bash
# Hangi projenin nerede olduğunu hatırlayamıyorsun
bookmark find shop                  # "shop" içeren tüm bookmark'lar
bookmark list -i                    # İnteraktif arama + seçim
```

## 🔧 Advanced Tips

### Numaralı Bookmark'ı İsimli Yap

```bash
cd /uzun/path/proje
bookmark .                          # #1 olarak kaydedilir
bookmark 1 -n myproject             # İsimli bookmark'a çevir
```

### Kategori Değiştirme

```bash
bookmark mv myproject to archive    # Kategoriye taşı
```

### Toplu Temizlik

```bash
bookmark clear                      # Tüm numaralı bookmark'ları sil (onay ister)
```

## 🐛 Troubleshooting

### Bookmark çalışmıyor

```bash
./setup.sh                          # Wrapper fonksiyonunu yeniden yükle
source ~/.bashrc                    # Shell'i reload et
```

### JSON dosyası bozuldu

```bash
cat ~/.mylinuxhelper/bookmarks.json | jq .  # Validasyon
# Bozuksa, yedekten geri yükle veya dosyayı sil (yeni oluşturulur)
```

### Path artık yok uyarısı

```bash
bookmark edit myproject             # Path'i güncelle
# veya
bookmark rm myproject               # Sil
```

---

**Son Güncelleme**: 2025-11-07  
**Versiyon**: MyLinuxHelper v1.0+

