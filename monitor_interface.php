<?php

use PEAR2\Net\RouterOS;

register_menu(" Interface Monitor", true, "monitorRouterInterface", 'AFTER_SETTINGS', 'ion-ios-pulse', "Hot", "red");

function monitorRouterInterface() {
    global $ui, $routes;
    _admin();
    $ui->assign('_title', 'Interface Monitor');
    $ui->assign('_system_menu', 'Interface Monitor');
    $admin = Admin::_info();
    $ui->assign('_admin', $admin);

    $routers = ORM::for_table('tbl_routers')->where('enabled', '1')->find_many();
    $routerId = $routes['2'] ?? $routers[0]['id'];

    // Fetch the interfaces
    $interfaces = monitorRouterGetInterfaces();

    $ui->assign('routers', $routers);
    $ui->assign('router', $routerId);
    $ui->assign('interfaces', $interfaces); // Assign interfaces to template

    $ui->display('monitor_interface.tpl');
}

function monitorRouterFormatBytes($bytes, $precision = 2)
{
    $units = ['B', 'KB', 'MB', 'GB', 'TB', 'PB', 'EB', 'ZB', 'YB'];
    $bytes = max($bytes, 0);
    $pow = floor(($bytes ? log($bytes) : 0) / log(1024));
    $pow = min($pow, count($units) - 1);
    $bytes /= pow(1024, $pow);
    return round($bytes, $precision) . ' ' . $units[$pow];
}




function monitorRouterGetInterfaces() {
    global $routes;
    $routerId = $routes['2'] ?? null;
    $mikrotik = ORM::for_table('tbl_routers')->where('enabled', '1')->find_one($routerId);
    $client = Mikrotik::getClient($mikrotik['ip_address'], $mikrotik['username'], $mikrotik['password']);
    $interfaces = $client->sendSync(new RouterOS\Request('/interface/print'));

    $interfaceList = [];
    foreach ($interfaces as $interface) {
        $name = $interface->getProperty('name');
        // Menghapus karakter khusus < dan >
        $name = str_replace(['<', '>'], '', $name);
        $interfaceList[] = ['name' => $name];
    }
    return $interfaceList;
}

function monitorRouterTraffic()
{
    $interface = $_GET["interface"]; // Ambil interface dari parameter GET
    global $routes;
    $router = $routes['2'];
    $mikrotik = ORM::for_table('tbl_routers')->where('enabled', '1')->find_one($router);
    $client = Mikrotik::getClient($mikrotik['ip_address'], $mikrotik['username'], $mikrotik['password']);

    try {
        $results = $client->sendSync(
            (new RouterOS\Request('/interface/monitor-traffic'))
                ->setArgument('interface', $interface)
                ->setArgument('once', '')
        );

        $rows = array();
        $rows2 = array();
        $labels = array();

        foreach ($results as $result) {
            $ftx = $result->getProperty('tx-bits-per-second');
            $frx = $result->getProperty('rx-bits-per-second');

            // Timestamp dalam milidetik (millisecond)
            $timestamp = time() * 1000;

            $rows[] = $ftx;
            $rows2[] = $frx;
            $labels[] = $timestamp; // Tambahkan timestamp ke dalam array labels
        }

        // Hitung total harian dari TX dan RX
        $dailyTotal = monitorRouterCalculateDailyTotal($interface);

        $result = array(
            'labels' => $labels,
            'rows' => array(
                'tx' => $rows,
                'rx' => $rows2
            ),
            'daily_total' => $dailyTotal  // Menyertakan total harian dalam respons JSON
        );
    } catch (Exception $e) {
        $result = array('error' => $e->getMessage());
    }

    // Set header untuk respons JSON
    header('Content-Type: application/json');
    echo json_encode($result);
}

function monitorRouterCalculateDailyTotal($interface) {
    global $routes;
    $router = $routes['2'];
    $mikrotik = ORM::for_table('tbl_routers')->where('enabled', '1')->find_one($router);
    $client = Mikrotik::getClient($mikrotik['ip_address'], $mikrotik['username'], $mikrotik['password']);

    // Menggunakan API MikroTik untuk mengambil data lalu lintas
    $request = new RouterOS\Request('/interface/monitor-traffic');
    $request->setArgument('interface', $interface);
    $request->setArgument('once', '');
    $request->setArgument('duration', '1d'); // Durasi untuk mengambil data lalu lintas selama satu hari

    $results = $client->sendSync($request);

    $totalTx = 0;
    $totalRx = 0;

    foreach ($results as $result) {
        $totalTx += $result->getProperty('tx-bits-per-second');
        $totalRx += $result->getProperty('rx-bits-per-second');
    }

    // Mengembalikan total TX dan RX dalam bit per detik
    return [
        'tx' => $totalTx,
        'rx' => $totalRx
    ];
}
