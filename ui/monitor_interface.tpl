{include file="sections/header.tpl"}
<style>
  .table-bordered {
      width: 100%;
      max-width: 100%;
      table-layout: fixed;
  }
  .table-bordered th, .table-bordered td {
      width: auto;
      overflow: hidden;
      text-overflow: ellipsis;
      white-space: nowrap;
      background: none;
      border: none;
      padding: 10px;
      vertical-align: middle;
      text-align: center;
  }
</style>
<div class="container mt-5">
  <div class="card">
    <div class="card-header">
    </div>
    <div class="card-body">
      <div class="form-group">
      </div>
      <div class="table-responsive mt-4">
        <table class="table table-bordered">
          <thead>
            <tr>
              <th>
                <select name="selectedNetworkInterface" id="selectedNetworkInterface" class="form-control custom-select" onchange="updateTrafficValues()">
                  {foreach from=$interfaces item=interface}
                    {if !strstr($interface.name, 'pppoe')} <!-- Tambahkan kondisi untuk menyaring 'pppoe' -->
                      <option value="{$interface.name|escape:'html'}">{$interface.name}</option>
                    {/if}
                  {/foreach}
                </select>
              </th>
                  <th id="tabletx"><i class="fa fa-download"></i></th>
                  <th id="tablerx"><i class="fa fa-upload"></i></th>
            </tr>
          </thead>
        </table>
      </div>
      <div id="chart" class="mt-3" style="width: auto; height: 500px;"></div>
    </div>
  </div>
</div>
<link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/font-awesome/6.0.0-beta3/css/all.min.css">
<script src="https://code.jquery.com/jquery-3.6.0.min.js"></script>
<script src="https://cdn.jsdelivr.net/npm/apexcharts"></script>
<script>
  var chart;
  var chartData = {
    txData: [],
    rxData: []
  };

  function createChart() {
    var options = {
      chart: {
        height: 350,
        type: 'area',
        animations: {
          enabled: true,
          easing: 'linear',
          speed: 200,
          animateGradually: {
            enabled: true,
            delay: 150
          },
          dynamicAnimation: {
            enabled: true,
            speed: 200
          }
        },
        events: {
          mounted: function(chartContext, config) {
            // Initially load data and set up refresh interval
            updateTrafficValues();
            setInterval(updateTrafficValues, 3000);
          }
        }
      },
      stroke: {
        curve: 'smooth'
      },
      series: [{
        name: 'Upload',
        data: chartData.txData
      }, {
        name: 'Download',
        data: chartData.rxData
      }],
      xaxis: {
        type: 'datetime',
        labels: {
          formatter: function(value) {
            return new Date(value).toLocaleTimeString();
          }
        }
      },
      yaxis: {
        title: {
          text: 'Lalu Lintas Langsung'
        },
        labels: {
          formatter: function(value) {
            return formatBytes(value);
          }
        }
      },
      tooltip: {
        x: {
          format: 'HH:mm:ss'
        },
        y: {
          formatter: function(value) {
            return formatBytes(value) + 'ps';
          }
        }
      },
      dataLabels: {
        enabled: true,
        formatter: function(value) {
          return formatBytes(value);
        }
      }
    };
    chart = new ApexCharts(document.querySelector("#chart"), options);
    chart.render();
  }

  function formatBytes(bytes) {
    if (bytes === 0) {
      return '0 B';
    }
    var k = 1024;
    var sizes = ['B', 'KB', 'MB', 'GB', 'TB', 'PB', 'EB', 'ZB', 'YB'];
    var i = Math.floor(Math.log(bytes) / Math.log(k));
    var formattedValue = parseFloat((bytes / Math.pow(k, i)).toFixed(2));
    return formattedValue + ' ' + sizes[i];
  }

function updateTrafficValues() {
  var selectedInterface = $('#selectedNetworkInterface').val(); // Mengambil nilai interface yang dipilih
  $.ajax({
    url: '{$_url}plugin/monitor_traffic/{$router}', // Pastikan URL ini sesuai dengan konfigurasi server Anda
    type: 'GET',
    dataType: 'json',
    data: {
      interface: selectedInterface
    },
    success: function(data) {
      if (data && data.rows) {
        var timestamp = new Date().getTime();
        var txData = data.rows.tx;
        var rxData = data.rows.rx;

        // Memperbarui data pada grafik
        if (txData.length > 0 && rxData.length > 0) {
          var TX = parseInt(txData[0]);
          var RX = parseInt(rxData[0]);

          // Menambahkan data baru ke chartData
          chartData.txData.push({ x: timestamp, y: TX });
          chartData.rxData.push({ x: timestamp, y: RX });

          // Memastikan hanya menyimpan maksimal 10 data points
          var maxDataPoints = 10;
          if (chartData.txData.length > maxDataPoints) {
            chartData.txData.shift();
            chartData.rxData.shift();
          }

          // Memperbarui seri pada grafik
          chart.updateSeries([{
            name: 'Upload',
            data: chartData.txData
          }, {
            name: 'Download',
            data: chartData.rxData
          }]);
        }

        // Memperbarui teks pada tabel TX dan RX dengan ikon
        document.getElementById("tabletx").innerHTML = '<i class="fas fa-upload"></i>  ' + formatBytes(TX);
        document.getElementById("tablerx").innerHTML = '<i class="fas fa-download"></i>  ' + formatBytes(RX);
      } else {
        // Jika tidak ada data, set nilai ke 0
        document.getElementById("tabletx").textContent = 'TX: 0 B';
        document.getElementById("tablerx").textContent = 'RX: 0 B';
      }
    },
    error: function(XMLHttpRequest, textStatus, errorThrown) {
      console.error("Status: " + textStatus + "; Error: " + errorThrown);
      // Menampilkan pesan error atau default value jika request gagal
      document.getElementById("tabletx").textContent = 'TX: Error';
      document.getElementById("tablerx").textContent = 'RX: Error';
    }
  });
}


  createChart(); // Create the chart on page load
</script>

<script>
  window.addEventListener('DOMContentLoaded', function() {
    var portalLink = "https://github.com/focuslinkstech";
    $('#version').html('MikroTik Monitor | Ver: 1.0 | by: <a href="' + portalLink + '">Focuslinks Tech</a>');
  });
</script>

{include file="sections/footer.tpl"}
