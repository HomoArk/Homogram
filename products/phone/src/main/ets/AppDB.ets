import sql from "@liushengyi/smartdb";
import relationalStore from "@ohos.data.relationalStore";
import { Logger } from '@ohos/base';

class AppDB {
  static DB_VERSION = 16;
  private static STORE_CONFIG: relationalStore.StoreConfig = {
    name: 'homo.db',
    securityLevel: relationalStore.SecurityLevel.S1,
    encrypt: false,
    isReadOnly: false
  };

  initDb(context: Context) {
    let appDbOpenHelper = new AppDbOpenHelper();
    sql.dbHelper.initDb(context, 'homo.db', AppDB.DB_VERSION, appDbOpenHelper)
      .catch((err: Error) => {
        Logger.error(`initDb failed due to ${err.name} - ${err.message}`);
      })
  }
}

class AppDbOpenHelper extends sql.DbOpenHelper {
  constructor() {
    super()
  }

  async onCreate(db: relationalStore.RdbStore) {
    Logger.debug("onCreate no app-owned Telegram cache tables to create")
  }

  async onUpgrade(db: relationalStore.RdbStore, oldVersion: number, newVersion: number) {
    Logger.debug(`onUpgrade oldVersion=${oldVersion}, newVersion=${newVersion}; Telegram cache is Rust-owned`)
  }
}

export default new AppDB()
