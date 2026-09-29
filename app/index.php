<?php
/**
 * PitStop Motors - Read-only Inventory Listing
 * Tech: PHP + PDO (pgsql). DB credentials are loaded at runtime from
 * /etc/pitstop/db.json (populated from AWS Secrets Manager).
 */
declare(strict_types=1);

// ---- DB connection ----
// Credentials come from /etc/pitstop/db.json, written at boot by the
// launch template user_data from AWS Secrets Manager (refreshed every
// 5 minutes to follow password rotation). Environment variables are a
// fallback for local development. No credentials live in this file.
$cfg = [];
$cfgFile = '/etc/pitstop/db.json';
if (is_readable($cfgFile)) {
    $cfg = json_decode((string)file_get_contents($cfgFile), true) ?: [];
}

$DB_HOST     = $cfg['host']     ?? (getenv('DB_HOST') ?: '');
$DB_PORT     = $cfg['port']     ?? (getenv('DB_PORT') ?: '5432');
$DB_NAME     = $cfg['dbname']   ?? (getenv('DB_NAME') ?: '');
$DB_USER     = $cfg['username'] ?? (getenv('DB_USER') ?: '');
$DB_PASSWORD = $cfg['password'] ?? (getenv('DB_PASSWORD') ?: '');
$DB_SSLMODE  = 'require'; // RDS PostgreSQL 15+ rejects unencrypted connections

$dsn = "pgsql:host={$DB_HOST};port={$DB_PORT};dbname={$DB_NAME};sslmode={$DB_SSLMODE}";

// ---- Connect and query (read-only) ----
// Everything that touches the database is inside try, so any failure
// shows a friendly message instead of a blank 500 page.
try {
    $pdo = new PDO($dsn, $DB_USER, $DB_PASSWORD, [
        PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION,
        PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC,
    ]);

    $sql = "SELECT id, sku, name, category, quantity, unit_cost_cad, supplier, purchaser, location, received_at
            FROM pitstop.inventory
            ORDER BY category ASC, name ASC";

    $stmt = $pdo->prepare($sql);
    $stmt->execute();
    $rows = $stmt->fetchAll();
} catch (Throwable $e) {
    // Details go to the PHP error log (/var/log/php-fpm/www-error.log), never to the browser
    error_log("Inventory page DB error: " . $e->getMessage());
    http_response_code(500);
    echo "<h1>Inventory is temporarily unavailable</h1>";
    echo "<p>Please check back later.</p>";
    exit;
}

// Compute totals
$total_items = 0;
$total_value = 0.0;
foreach ($rows as $r) {
    $total_items += (int)$r['quantity'];
    $total_value += ((float)$r['unit_cost_cad']) * (int)$r['quantity'];
}

// Helper: escape output for HTML
function h($v) { return htmlspecialchars((string)$v, ENT_QUOTES, 'UTF-8'); }
?>
<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>PitStop Motors | Inventory</title>
  <link rel="stylesheet" href="assets/inventory.css">
  <meta name="robots" content="noindex, nofollow">
</head>
<body>
  <header class="header">
    <div class="container">
      <h1>Inventory</h1>
    </div>
  </header>

  <main class="container">
    <div class="card">
      <div class="controls">
        <input type="text" placeholder="Search (client-side only)" aria-label="Search filter" oninput="filterTable(this.value)">
        <select aria-label="Category filter" onchange="filterCategory(this.value)">
          <option value="">All categories</option>
<?php
// Build simple category list (from current rows)
$cats = [];
foreach ($rows as $r) { $cats[$r['category']] = true; }
ksort($cats);
foreach (array_keys($cats) as $c) {
    echo '          <option value="'.h($c).'">'.h($c)."</option>\n";
}
?>
        </select>
        <span class="muted">Total items: <strong><?php echo number_format($total_items); ?></strong> • Total value: <strong>$<?php echo number_format($total_value, 2); ?></strong></span>
      </div>

      <div class="table-wrap">
        <table id="inv">
          <thead>
            <tr>
              <th>SKU</th>
              <th>Name</th>
              <th>Category</th>
              <th class="muted">Supplier</th>
              <th>Qty</th>
              <th>Unit Cost</th>
              <th>Location</th>
              <th>Purchaser</th>
              <th>Received</th>
            </tr>
          </thead>
          <tbody>
<?php foreach ($rows as $r): ?>
            <tr data-category="<?php echo h($r['category']); ?>">
              <td><code><?php echo h($r['sku']); ?></code></td>
              <td><?php echo h($r['name']); ?></td>
              <td><span class="tag"><?php echo h($r['category']); ?></span></td>
              <td class="muted"><?php echo h($r['supplier']); ?></td>
              <td><?php echo number_format((int)$r['quantity']); ?></td>
              <td>$<?php echo number_format((float)$r['unit_cost_cad'], 2); ?></td>
              <td><?php echo h($r['location']); ?></td>
              <td><?php echo h($r['purchaser']); ?></td>
              <td><?php echo h($r['received_at']); ?></td>
            </tr>
<?php endforeach; ?>
          </tbody>
          <tfoot>
            <tr>
              <td colspan="4">Totals</td>
              <td><?php echo number_format($total_items); ?></td>
              <td>$<?php echo number_format($total_value, 2); ?></td>
              <td colspan="3"></td>
            </tr>
          </tfoot>
        </table>
      </div>
      <div class="footer">Read‑only listing. For updates, use the internal inventory admin tools. Developed by Hassan Ayinde</div>
    </div>
  </main>

  <script>
    function filterTable(q){
      q = (q || '').toLowerCase();
      const rows = document.querySelectorAll('#inv tbody tr');
      rows.forEach(tr => {
        const text = tr.innerText.toLowerCase();
        tr.style.display = text.includes(q) ? '' : 'none';
      });
    }
    function filterCategory(cat){
      const rows = document.querySelectorAll('#inv tbody tr');
      rows.forEach(tr => {
        if(!cat){ tr.style.display = ''; return; }
        tr.style.display = (tr.getAttribute('data-category') === cat) ? '' : 'none';
      });
    }
  </script>
</body>
</html>