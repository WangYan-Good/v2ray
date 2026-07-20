package nginx

import (
	"errors"
	"fmt"
	"io/fs"
	"os"
	"path/filepath"
)

type fileSnapshot struct {
	path    string
	backup  string
	mode    fs.FileMode
	existed bool
}

type fileTransaction struct {
	backupDir string
	dryRun    bool
	files     []fileSnapshot
	seen      map[string]bool
}

func newFileTransaction(root string, dryRun bool) (*fileTransaction, error) {
	tx := &fileTransaction{dryRun: dryRun, seen: make(map[string]bool)}
	if dryRun {
		return tx, nil
	}
	tmpDir := rootedPath(root, "/tmp")
	if err := os.MkdirAll(tmpDir, 0o755); err != nil {
		return nil, err
	}
	backupDir, err := os.MkdirTemp(tmpDir, "xray-nginx-backup-")
	if err != nil {
		return nil, err
	}
	tx.backupDir = backupDir
	return tx, nil
}

func (tx *fileTransaction) Track(path string) error {
	if tx.seen[path] {
		return nil
	}
	tx.seen[path] = true
	snapshot := fileSnapshot{path: path}
	info, err := os.Stat(path)
	if errors.Is(err, os.ErrNotExist) {
		tx.files = append(tx.files, snapshot)
		return nil
	}
	if err != nil {
		return err
	}
	snapshot.existed = true
	snapshot.mode = info.Mode().Perm()
	if !tx.dryRun {
		data, err := os.ReadFile(path)
		if err != nil {
			return err
		}
		snapshot.backup = filepath.Join(tx.backupDir, fmt.Sprintf("%03d", len(tx.files)))
		if err := os.WriteFile(snapshot.backup, data, snapshot.mode); err != nil {
			return err
		}
	}
	tx.files = append(tx.files, snapshot)
	return nil
}

func (tx *fileTransaction) Rollback(skip map[string]bool) error {
	if tx.dryRun {
		return nil
	}
	var rollbackErr error
	for index := len(tx.files) - 1; index >= 0; index-- {
		snapshot := tx.files[index]
		if skip[snapshot.path] {
			continue
		}
		if !snapshot.existed {
			if err := os.Remove(snapshot.path); err != nil && !errors.Is(err, os.ErrNotExist) {
				rollbackErr = errors.Join(rollbackErr, fmt.Errorf("remove %s: %w", snapshot.path, err))
			}
			continue
		}
		data, err := os.ReadFile(snapshot.backup)
		if err != nil {
			rollbackErr = errors.Join(rollbackErr, err)
			continue
		}
		if err := atomicWriteFile(snapshot.path, data, snapshot.mode); err != nil {
			rollbackErr = errors.Join(rollbackErr, err)
		}
	}
	return rollbackErr
}

func (tx *fileTransaction) Close() {
	if tx.backupDir != "" {
		_ = os.RemoveAll(tx.backupDir)
	}
}

func atomicWriteFile(path string, data []byte, mode fs.FileMode) error {
	if err := os.MkdirAll(filepath.Dir(path), 0o755); err != nil {
		return err
	}
	tmp, err := os.CreateTemp(filepath.Dir(path), ".xray-write-*")
	if err != nil {
		return err
	}
	tmpPath := tmp.Name()
	defer os.Remove(tmpPath)
	if _, err := tmp.Write(data); err != nil {
		tmp.Close()
		return err
	}
	if err := tmp.Chmod(mode); err != nil {
		tmp.Close()
		return err
	}
	if err := tmp.Sync(); err != nil {
		tmp.Close()
		return err
	}
	if err := tmp.Close(); err != nil {
		return err
	}
	return os.Rename(tmpPath, path)
}

func rootedPath(root, path string) string {
	if root == "" || root == "/" {
		return path
	}
	return filepath.Join(root, path[1:])
}
