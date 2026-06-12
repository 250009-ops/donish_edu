import { query } from "../db/pool.js";

const MAX_UPLOAD_BYTES = 50 * 1024 * 1024;

export { MAX_UPLOAD_BYTES };

/** @param {'android'|'ios'} platform */
export async function getCurrentArtifact(platform) {
  const { rows } = await query(
    `select * from app_artifacts where platform = $1 and is_current = true limit 1`,
    [platform]
  );
  return rows[0] || null;
}

export async function setCurrentAndroidArtifact({
  fileId,
  fileUniqueId,
  fileName,
  sizeBytes,
  versionName,
  uploadedBy
}) {
  await query(`update app_artifacts set is_current = false where platform = 'android'`);
  const { rows } = await query(
    `insert into app_artifacts
       (platform, version_name, file_id, file_unique_id, file_name, size_bytes, uploaded_by, is_current)
     values ('android', $1, $2, $3, $4, $5, $6, true)
     returning *`,
    [fileId, fileUniqueId, fileName, sizeBytes, versionName, uploadedBy]
  );
  return rows[0];
}

export async function setCurrentIosArtifact({ storeUrl, versionName, uploadedBy }) {
  await query(`update app_artifacts set is_current = false where platform = 'ios'`);
  const { rows } = await query(
    `insert into app_artifacts
       (platform, version_name, store_url, uploaded_by, is_current)
     values ('ios', $1, $2, $3, true)
     returning *`,
    [versionName, storeUrl, uploadedBy]
  );
  return rows[0];
}
