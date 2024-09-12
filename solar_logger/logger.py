import json
import urllib3
import schedule
import sqlite3
import psutil as ps
import board
import adafruit_tsl2591

from datetime import datetime
from time import sleep

import config

class Sensor:
  def __init__(self, name, schema, format):
    self.name = name
    self.schema = schema
    self.format = format
    self.enabled = False

  def setup(self):
    pass

  def collect(self, dt):
    return {'at': dt, 'table': self.name, 'data': self.sensor_data()}

  def print(self, data):
    print(self.format.format_map(data))

  def sensor_data(self):
    return {}


tls2591_columns = [
  ('visible', 'INTEGER'),
  ('infrared', 'INTEGER'),
  ('lux', 'REAL')
]

tls2591_format = "LIGHT // Visible: {visible:,d}, Infrared: {infrared:,d}, Lux: {lux:,.0f}"

class Tls2591Sensor(Sensor):
  def __init__(self):
    super().__init__('luminosity', tls2591_columns, tls2591_format)

  def setup(self):
    try:
      # Create sensor object, communicating over the board's default I2C bus
      i2c = board.I2C()  # uses board.SCL and board.SDA
      # i2c = board.STEMMA_I2C()  # For using the built-in STEMMA QT connector on a microcontroller

      # Create the TSL2591 instance, passing in the I2C bus
      self.tsl = adafruit_tsl2591.TSL2591(i2c)

      # You can optionally change the gain and integration time:
      self.tsl.gain = adafruit_tsl2591.GAIN_LOW

      # self.tsl.gain = adafruit_tsl2591.GAIN_LOW (1x gain)
      # self.tsl.gain = adafruit_tsl2591.GAIN_MED (25x gain, the default)
      # self.tsl.gain = adafruit_tsl2591.GAIN_HIGH (428x gain)
      # self.tsl.gain = adafruit_tsl2591.GAIN_MAX (9876x gain)
      # self.tsl.integration_time = adafruit_tsl2591.INTEGRATIONTIME_100MS (100ms, default)
      # self.tsl.integration_time = adafruit_tsl2591.INTEGRATIONTIME_200MS (200ms)
      # self.tsl.integration_time = adafruit_tsl2591.INTEGRATIONTIME_300MS (300ms)
      # self.tsl.integration_time = adafruit_tsl2591.INTEGRATIONTIME_400MS (400ms)
      # self.tsl.integration_time = adafruit_tsl2591.INTEGRATIONTIME_500MS (500ms)
      # self.tsl.integration_time = adafruit_tsl2591.INTEGRATIONTIME_600MS (600ms)

      self.enabled = True

    except AttributeError as e:
      print(f'Tls2591 sensor not enabled: {e}')

  def sensor_data(self):
    visible = self.tsl.visible
    infrared = self.tsl.infrared
    lux = self.tsl.lux
    return {'visible': visible, 'infrared': infrared, 'lux': lux}


cpu_columns = [
  ('user', 'REAL'),
  ('nice', 'REAL'),
  ('system', 'REAL'),
  ('idle', 'REAL'),
  ('iowait', 'REAL'),
  ('irq', 'REAL'),
  ('softirq', 'REAL'),
  ('steal', 'REAL'),
  ('guest', 'REAL'),
  ('guest_nice', 'REAL')
]

cpu_format = "CPU TIME // User: {user:,.0f}, System: {system:,.0f}, Idle: {idle:,.0f}"

class PsCpuSensor(Sensor):
  def __init__(self):
    super().__init__('cpu', cpu_columns, cpu_format)

  def setup(self):
    self.enabled = True

  def sensor_data(self):
    cpu_data = ps.cpu_times()._asdict()
    data = {}
    for key in [col[0] for col in self.schema if col[0] in cpu_data]:
      data[key] = cpu_data[key]
    return data

vmemory_columns = [
  ('total', 'INTEGER'),
  ('available', 'INTEGER'),
  ('percent', 'REAL'),
  ('used', 'INTEGER'),
  ('free', 'INTEGER'),
  ('active', 'INTEGER'),
  ('inactive', 'INTEGER'),
  ('buffers', 'INTEGER'),
  ('cached', 'INTEGER'),
  ('shared', 'INTEGER'),
  ('slab', 'INTEGER')
]

vmemory_format = "VIRT MEM // Total: {total:,d}, Available: {available:,d}"

class PsVmemorySensor(Sensor):
  def __init__(self):
    super().__init__('vmemory', vmemory_columns, vmemory_format)

  def setup(self):
    self.enabled = True

  def sensor_data(self):
    vm_data = ps.virtual_memory()._asdict()
    data = {}
    for key in [col[0] for col in self.schema if col[0] in vm_data]:
      data[key] = vm_data[key]
    return data


# a configuration for jsonbin.io (these do not really exist!)
bin_id     = '66da5c4ce41b4d34e42ae0c4'
master_key = '$2a$10$wnduVxwwHRhr03T2Krbi3er8FCBY52jhA47eUCULKVdqbNU6KKF/K'
access_key = '$2a$10$aLiVcVn5tpmLh1M63GLJuu072wm8b20Ph.kMmrSnRmXBwfdKNfwAO'
update_method  = 'PUT'
update_url     = f'https://api.jsonbin.io/v3/b/{bin_id}'
update_headers = {
  'X-Master-Key': master_key,
  'X-Access-Key': access_key
}

class Logger:
  def __init__(self, dbfile, *sensors, **kwargs):
    self.dbfile         = dbfile
    self.sensors        = {sensor.name: sensor for sensor in sensors}
    self.any_enabled    = False
    self.http           = urllib3.PoolManager()
    self.update_method  = kwargs.get('update_method', 'PUT')
    self.update_url     = kwargs.get('update_url', 'http://localhost/uploads')
    self.update_headers = kwargs.get('update_headers', { })

  def find_sensor(self, name):
    return self.sensors.get(name)

  def setup(self):
    dt = datetime.utcnow()
    print('Logger startup')
    print("-" * 60)
    print("~~ {0:%Y-%m-%d %H:%M:%S} UTC ~~".format(dt))

    self.setup_db()

    enabled = []
    for sensor in self.sensors.values():
      sensor.setup()
      if sensor.enabled:
        enabled.append(sensor.name)

    if enabled:
      any_enabled = True
      enabled = f'''Sensors {', '.join(enabled)} enabled'''
    else:
      enabled = 'No sensors enabled'

    print(f'Database at {self.dbfile}')
    print(enabled)
    print(f'Updates to {self.update_url}')

  def setup_db(self):
    conn = sqlite3.connect(self.dbfile)
    cursor = conn.cursor()

    for sensor in self.sensors.values():
      cols = [f'{col[0]} {col[1]}' for col in sensor.schema]
      cursor.execute(f'''CREATE TABLE IF NOT EXISTS {sensor.name}
        (source_id INTEGER PRIMARY KEY, at REAL, sent REAL, {', '.join(cols)})''')

    conn.close()

  def collect_and_log(self):
    dt, all_data = self.collect_data()
    self.print_data(dt, all_data)
    self.log_data(all_data)

  def collect_data(self):
    '''Collect data and assign to class variable'''
    now = datetime.utcnow()
    all_data = []
    for sensor in self.sensors.values():
      if sensor.enabled:
        all_data.append(sensor.collect(now))
    return (now, all_data)

  def print_data(self, dt, all_data):
    '''Print data in nicely formatted string'''
    print("-" * 60)
    print("~~ {0:%Y-%m-%d, %H:%M:%S} UTC ~~".format(dt))
    if all_data:
      for sensor_data in all_data:
        table = sensor_data['table']
        sensor = self.find_sensor(table)
        if sensor:
          sensor.print(sensor_data['data'])
        else:
          print(f'Sensor not found {table}')
    else:
      print('No data')

  def log_data(self, all_data):
    '''Log the data into sqlite database'''
    conn = sqlite3.connect(self.dbfile)
    cursor = conn.cursor()

    for sensor_data in all_data:
      table = sensor_data['table']
      dt = sensor_data['at']
      data = sensor_data['data']
      cols = ['at'] + list(data.keys())
      values = [dt] + list(data.values())
      params = ','.join('?' * len(cols))
      cursor.execute(f'''INSERT INTO {table} ({', '.join(cols)}) VALUES({params})''', values)
      conn.commit()

    conn.close()

  def upload_unsent_data(self, tables = 'all'):
    all_data = self.fetch_unsent_data(tables)
    for table, rows in all_data.items():
      ids_to_mark = self.upload_data(table, rows)
      self.mark_sent(table, ids_to_mark)

  def fetch_unsent_data(self, tables = 'all'):
    if tables == 'all':
      tables = list(self.sensors.keys())
    elif isinstance(tables, str):
      tables = [tables]
    elif not isinstance(tables, list):
      tables = []

    if tables == []:
      return

    conn = sqlite3.connect(self.dbfile)
    conn.row_factory = sqlite3.Row
    cursor = conn.cursor()

    all_data = {}

    for table in tables:
      res = cursor.execute(f'SELECT * FROM {table} WHERE sent IS NULL')

      table_data = []
      for row in res:
        row_data = {key: row[key] for key in row.keys()}
        table_data.append(row_data)

      all_data[table] = table_data

    conn.close()

    return all_data

  def upload_data(self, table, rows):
    '''Send records to cloud server. Per jsonbin.io, the response should be:
    {'record': data, 'metadata': {'parentId': bin_id, 'private': True}}
    '''
    if rows == []:
      return []

    headers = {
      'Content-Type': 'application/json',
      'Accept': 'application/json'
    }
    headers.update(self.update_headers)

    data = {'table': table, 'rows': rows}
    print(f'uploading {len(rows)} rows for {table}')
    try:
      resp = self.http.request(self.update_method, self.update_url, headers=headers, json=data)
      print(f'response status {resp.status}')

      if resp.status < 200 or resp.status >= 300:
        return []

      # get row ids that were accepted by cloud server
      rows = resp.json()['record']['rows']
      ids = [row['source_id'] for row in rows if 'source_id' in row]
      return ids
    except:
      print(f'no connection to {self.update_url}')
      return []

  def mark_sent(self, table, ids):
    '''Mark database records as sent'''

    if len(ids) == 0:
      return

    print(f'marking {table} ids {ids}')
    now = datetime.utcnow()
    where_params = ','.join('?' * len(ids))

    conn = sqlite3.connect(self.dbfile)
    cursor = conn.cursor()
    res = cursor.execute(f'UPDATE {table} SET sent = ? WHERE source_id IN ({where_params})', (now, *ids))
    rowcount = cursor.rowcount
    conn.commit()
    conn.close()

    print(f'{rowcount} rows marked')


def factory(classname):
  cls = globals()[classname]
  return cls()

def main():
  sensors = [factory(sensor) for sensor in config.sensors]
  logger = Logger('datalogger.db', *sensors, update_url = config.update_url, headers = config.update_headers)
  logger.setup()
  schedule.every(1).seconds.do(logger.collect_and_log)
  schedule.every(10).seconds.do(logger.upload_unsent_data)

  while True:
    schedule.run_pending()
    sleep(0.5)

if __name__ == '__main__':
  main()
