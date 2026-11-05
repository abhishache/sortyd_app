package com.sortyd.app.data.db

import android.content.Context
import androidx.room.Database
import androidx.room.Room
import androidx.room.RoomDatabase
import androidx.room.migration.Migration
import androidx.sqlite.db.SupportSQLiteDatabase
import com.sortyd.app.data.model.TaskEntity
import com.sortyd.app.data.model.TaskListEntity
import com.sortyd.app.data.model.SnapshotEntity

@Database(
    entities = [TaskListEntity::class, TaskEntity::class, SnapshotEntity::class],
    version = 4,
    exportSchema = false,
)
abstract class SortydDatabase : RoomDatabase() {

    abstract fun sortydDao(): SortydDao

    companion object {
        @Volatile
        private var INSTANCE: SortydDatabase? = null

        private val MIGRATION_2_3 = object : Migration(2, 3) {
            override fun migrate(db: SupportSQLiteDatabase) {
                db.execSQL(
                    "ALTER TABLE tasks ADD COLUMN notificationLeadMinutes INTEGER NOT NULL DEFAULT 0"
                )
            }
        }

        private val MIGRATION_3_4 = object : Migration(3, 4) {
            override fun migrate(db: SupportSQLiteDatabase) {
                // Old releases allowed duplicate daily snapshots. Keep the newest record before
                // enforcing the one-snapshot-per-list-per-day invariant.
                db.execSQL(
                    "DELETE FROM snapshots WHERE rowid NOT IN (" +
                        "SELECT MAX(rowid) FROM snapshots GROUP BY listId, date)"
                )
                db.execSQL(
                    "CREATE UNIQUE INDEX IF NOT EXISTS index_snapshots_listId_date " +
                        "ON snapshots (listId, date)"
                )
            }
        }

        fun getInstance(context: Context): SortydDatabase {
            return INSTANCE ?: synchronized(this) {
                val instance = Room.databaseBuilder(
                    context.applicationContext,
                    SortydDatabase::class.java,
                    "sortyd_database"
                )
                    .addMigrations(MIGRATION_2_3, MIGRATION_3_4)
                    .build()
                INSTANCE = instance
                instance
            }
        }
    }
}
