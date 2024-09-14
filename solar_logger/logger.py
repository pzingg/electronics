import adafruit_tsl2591
import board
import json
import logging
import psutil as ps
import schedule
import sqlite3
import urllib3

from datetime import datetime
from time import sleep
from urllib.parse import parse_qs

import config

logger = logging.getLogger('logger')

def interp(x, x1, x2, y1, y2):
  return (x - x1) * (y2 - y1) / (x2 - x1) + y1

class Sensor:
  def __init__(self, name, schema, format):
    self.name = name
    self.schema = schema
    self.format = format
    self.enabled = False

  def setup(self):
    pass

  def collect(self, dt, tag):
    data = self.sensor_data(tag)
    if data:
      return {'table': self.name, 'at': dt, 'data': data}
    else:
      return None

  def print_log(self, data):
    logger.info(self.format.format_map(data))

  def sensor_data(self, tag):
    return {}

_TSL2591_LUX_DF = 408.0
_TSL2591_LUX_COEFB = 1.64
_TSL2591_LUX_COEFC = 0.59
_TSL2591_LUX_COEFD = 0.86

tls2591_columns = [
  ('visible', 'INTEGER'),
  ('infrared', 'INTEGER'),
  ('lux', 'REAL')
]

tls2591_format = 'Luminosity visible: {visible:,d}, infrared: {infrared:,d}, lux: {lux:,.0f}'

def option_in_tag(tag, key):
  parts = tag.split(',')
  for p in parts:
    d = parse_qs(p.strip())
    if key in d:
      return d[key][0]
  return None

class Tsl2591Sensor(Sensor):
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
      # Uncomment to test overflow:
      # self.tsl = MockTsl2591()
      # self.enabled = True
      logger.error(f'Tsl2591 init error: {e}')

  def sensor_data(self, tag):
    # In bright light Tsl2591 can throw a RuntimeError when
    # fetching lux value:
    # Overflow reading light channels!, Try to reduce the gain of
    #   the sensor using adafruit_tsl2591.GAIN_LOW
    # Unfortunately we are already running at GAIN_LOW
    try:
      visible = self.tsl.visible
    except RuntimeError as e:
      logger.error(f'Tsl2591 visible read error: {e}')
      visible = None

    try:
      infrared = self.tsl.infrared
    except RuntimeError as e:
      logger.error(f'Tsl2591 infrared read error: {e}')
      infrared = None

    try:
      lux = self.tsl.lux
    except RuntimeError as e:
      logger.error(f'Tsl2591 lux read error: {e}')
      lux = None

    if visible and infrared:
      if lux is None:
        # From the adafruit_tsl2591 source code
        atime = 100.0
        again = 1.0
        cpl = (atime * again) / _TSL2591_LUX_DF
        channel_0 = (visible + infrared) & 0xFFFF
        channel_1 = infrared
        lux1 = (channel_0 - (_TSL2591_LUX_COEFB * channel_1)) / cpl
        lux2 = ((_TSL2591_LUX_COEFC * channel_0) - (_TSL2591_LUX_COEFD * channel_1)) / cpl
        lux = max(lux1, lux2)
        if tag:
          tag = f'{tag},overflow'
        else:
          tag = 'overflow'
        logger.warning(f'Tsl2591 calculated lux {lux}')

      nd = option_in_tag(tag, 'nd')
      if nd:
        try:
          nd = float(nd)
          lux = lux * nd
        except:
          pass

      return {'tag': tag, 'visible': visible, 'infrared': infrared, 'lux': lux}
    else:
      return None

# Class for testing only
class MockTsl2591:
  @property
  def visible(self):
    return 554840886

  @property
  def infrared(self):
    return 8478

  @property
  def lux(self):
    raise RuntimeError('overflow - use smaller gain')

class MockTsl2591Sensor(Tsl2591Sensor):
  def __init__(self):
    super().__init__()

  def setup(self):
    self.tsl = MockTsl2591()
    self.enabled = True

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

cpu_format = 'Cpu time user: {user:,.0f}, system: {system:,.0f}, idle: {idle:,.0f}'

class PsCpuSensor(Sensor):
  def __init__(self):
    super().__init__('cpu', cpu_columns, cpu_format)

  def setup(self):
    self.enabled = True

  def sensor_data(self, tag):
    cpu_data = ps.cpu_times()._asdict()
    data = {'tag': tag}
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

vmemory_format = 'Virtual memory total: {total:,d}, available: {available:,d}'

class PsVmemorySensor(Sensor):
  def __init__(self):
    super().__init__('vmemory', vmemory_columns, vmemory_format)

  def setup(self):
    self.enabled = True

  def sensor_data(self, tag):
    vm_data = ps.virtual_memory()._asdict()
    data = {'tag': tag}
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
    self.tag            = kwargs.get('tag')
    self.update_method  = kwargs.get('update_method', 'PUT')
    self.update_url     = kwargs.get('update_url', 'http://localhost/uploads')
    self.update_headers = kwargs.get('update_headers', { })

  def find_sensor(self, name):
    return self.sensors.get(name)

  def setup(self):
    dt = datetime.utcnow()
    logger.info('Logger startup')

    self.setup_db()

    enabled = []
    for sensor in self.sensors.values():
      sensor.setup()
      if sensor.enabled:
        enabled.append(sensor.name)

    if enabled:
      any_enabled = True
      enabled = f'''Sensors: {', '.join(enabled)}'''
    else:
      enabled = 'Sensors: none'

    logger.info(f'Tag: {self.tag}')
    logger.info(f'Database: {self.dbfile}')
    logger.info(enabled)
    logger.info(f'Updates: {self.update_url}')

  def setup_db(self):
    conn = sqlite3.connect(self.dbfile)
    cursor = conn.cursor()

    for sensor in self.sensors.values():
      cols = [f'{col[0]} {col[1]}' for col in sensor.schema]
      cursor.execute(f'''CREATE TABLE IF NOT EXISTS {sensor.name}
        (source_id INTEGER PRIMARY KEY, tag TEXT, at REAL, sent REAL, {', '.join(cols)})''')

    conn.close()

  def collect_and_log(self):
    dt, all_data = self.collect_data()
    self.print_log(dt, all_data)
    self.persist_data(all_data)

  def collect_data(self):
    '''Collect data from all enabled sensors'''
    now = datetime.utcnow()

    all_data = []
    for sensor in self.sensors.values():
      if sensor.enabled:
        sensor_data = sensor.collect(now, self.tag)
        if sensor_data:
          all_data.append(sensor_data)

    return (now, all_data)

  def print_log(self, dt, all_data):
    '''Write logger data in nicely formatted string'''
    if all_data:
      for sensor_data in all_data:
        table = sensor_data['table']
        sensor = self.find_sensor(table)
        if sensor:
          sensor.print_log(sensor_data['data'])
        else:
          logger.error(f'Sensor not found: {table}')
    else:
      logger.info('No sensor data')

  def persist_data(self, all_data):
    '''Persist the data into the sqlite database'''
    if not all_data:
      return

    conn = sqlite3.connect(self.dbfile)
    cursor = conn.cursor()

    for sensor_data in all_data:
      table  = sensor_data['table']
      dt     = sensor_data['at']
      data   = sensor_data['data']
      cols   = ['at'] + list(data.keys())
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
    logger.info(f'Uploading {len(rows)} rows for {table}')
    try:
      resp = self.http.request(self.update_method, self.update_url, headers=headers, json=data)
      logger.debug(f'Response status {resp.status}')

      if resp.status < 200 or resp.status >= 300:
        return []

      # get row ids that were accepted by cloud server
      rows = resp.json()['record']['rows']
      ids = [row['source_id'] for row in rows if 'source_id' in row]
      return ids
    except:
      logger.error(f'No connection to {self.update_url}')
      return []

  def mark_sent(self, table, ids):
    '''Mark database records as sent'''
    if len(ids) == 0:
      return

    logger.debug(f'Table {table}: marking ids {ids}')
    now = datetime.utcnow()
    where_params = ','.join('?' * len(ids))

    conn = sqlite3.connect(self.dbfile)
    cursor = conn.cursor()
    res = cursor.execute(f'UPDATE {table} SET sent = ? WHERE source_id IN ({where_params})', (now, *ids))
    rowcount = cursor.rowcount
    conn.commit()
    conn.close()

    logger.info(f'Table {table}: {rowcount} rows marked')


def factory(classname):
  cls = globals()[classname]
  return cls()

def main():
  logging.basicConfig(
    filename='datalogger.log',
    level=logging.INFO,
    format='%(asctime)s %(name)s [%(levelname)s] %(message)s'
  )

  sensors = [factory(sensor) for sensor in config.sensors]
  logger = Logger('datalogger.db', *sensors, tag = config.tag, update_url = config.update_url, headers = config.update_headers)
  logger.setup()

  collection_interval = config.collection_interval
  sync_interval = min(20 * collection_interval, 300)
  schedule.every(collection_interval).seconds.do(logger.collect_and_log)
  schedule.every(sync_interval).seconds.do(logger.upload_unsent_data)

  while True:
    schedule.run_pending()
    sleep(1)

if __name__ == '__main__':
  main()
