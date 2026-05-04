package main

import (
	"errors"
	"fmt"
	"io"
	"log"
	"net/http"
	"net/url"
	"os"
	"path"
	"path/filepath"
	"strings"
	"syscall"
)

const (
	addr        = ":8081"
	basePrefix  = "/webdav"
	storageRoot = "./storage"

	username = "webdavuser"
	password = "StrongPass!"
)

func main() {
	if err := os.MkdirAll(storageRoot, 0755); err != nil {
		log.Fatal(err)
	}

	srv := &server{
		root:       storageRoot,
		basePrefix: basePrefix,
		username:   username,
		password:   password,
	}

	log.Printf("GO09_01s listening on http://localhost%s%s", addr, basePrefix)
	log.Printf("storage root: %s", storageRoot)
	log.Fatal(http.ListenAndServe(addr, srv))
}

type server struct {
	root       string
	basePrefix string
	username   string
	password   string
}

func (s *server) ServeHTTP(w http.ResponseWriter, r *http.Request) {
	if !s.checkAuth(w, r) {
		return
	}

	if !strings.HasPrefix(r.URL.Path, s.basePrefix) {
		http.NotFound(w, r)
		return
	}

	switch r.Method {
	case "MKCOL":
		s.handleMKCOL(w, r)
	case "PUT":
		s.handlePUT(w, r)
	case "GET":
		s.handleGET(w, r)
	case "COPY":
		s.handleCOPY(w, r)
	case "MOVE":
		s.handleMOVE(w, r)
	case "DELETE":
		s.handleDELETE(w, r)
	default:
		w.Header().Set("Allow", "MKCOL, PUT, GET, COPY, MOVE, DELETE")
		http.Error(w, "method not allowed", http.StatusMethodNotAllowed)
	}
}

func (s *server) checkAuth(w http.ResponseWriter, r *http.Request) bool {
	user, pass, ok := r.BasicAuth()
	if !ok || user != s.username || pass != s.password {
		w.Header().Set("WWW-Authenticate", `Basic realm="GO09_01s WebDAV"`)
		http.Error(w, "unauthorized", http.StatusUnauthorized)
		return false
	}
	return true
}

func (s *server) resolveRequestPath(requestPath string) (string, error) {
	rel := strings.TrimPrefix(requestPath, s.basePrefix)
	rel = strings.TrimPrefix(rel, "/")

	clean := path.Clean("/" + rel)
	fsPath := filepath.Join(s.root, filepath.FromSlash(strings.TrimPrefix(clean, "/")))

	rootAbs, err := filepath.Abs(s.root)
	if err != nil {
		return "", err
	}
	pathAbs, err := filepath.Abs(fsPath)
	if err != nil {
		return "", err
	}

	relCheck, err := filepath.Rel(rootAbs, pathAbs)
	if err != nil {
		return "", err
	}
	if relCheck == ".." || strings.HasPrefix(relCheck, ".."+string(filepath.Separator)) {
		return "", fmt.Errorf("invalid path")
	}

	return pathAbs, nil
}

func (s *server) resolveDestination(r *http.Request) (string, error) {
	dst := r.Header.Get("Destination")
	if dst == "" {
		return "", fmt.Errorf("missing Destination header")
	}

	u, err := url.Parse(dst)
	if err != nil {
		return "", fmt.Errorf("invalid Destination header")
	}

	dstPath := u.Path
	if dstPath == "" {
		dstPath = dst
	}

	if !strings.HasPrefix(dstPath, s.basePrefix) {
		return "", fmt.Errorf("destination must stay under %s", s.basePrefix)
	}

	return s.resolveRequestPath(dstPath)
}

func (s *server) handleMKCOL(w http.ResponseWriter, r *http.Request) {
	target, err := s.resolveRequestPath(r.URL.Path)
	if err != nil {
		http.Error(w, err.Error(), http.StatusBadRequest)
		return
	}

	if _, err := os.Stat(target); err == nil {
		http.Error(w, "collection already exists", http.StatusMethodNotAllowed)
		return
	}

	parent := filepath.Dir(target)
	info, err := os.Stat(parent)
	if err != nil || !info.IsDir() {
		http.Error(w, "parent collection does not exist", http.StatusConflict)
		return
	}

	if err := os.Mkdir(target, 0755); err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}

	w.WriteHeader(http.StatusCreated)
}

func (s *server) handlePUT(w http.ResponseWriter, r *http.Request) {
	target, err := s.resolveRequestPath(r.URL.Path)
	if err != nil {
		http.Error(w, err.Error(), http.StatusBadRequest)
		return
	}

	parent := filepath.Dir(target)
	info, err := os.Stat(parent)
	if err != nil || !info.IsDir() {
		http.Error(w, "parent collection does not exist", http.StatusConflict)
		return
	}

	_, existedErr := os.Stat(target)
	existed := existedErr == nil

	f, err := os.Create(target)
	if err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}
	defer f.Close()

	if _, err := io.Copy(f, r.Body); err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}

	if existed {
		w.WriteHeader(http.StatusNoContent)
	} else {
		w.WriteHeader(http.StatusCreated)
	}
}

func (s *server) handleGET(w http.ResponseWriter, r *http.Request) {
	target, err := s.resolveRequestPath(r.URL.Path)
	if err != nil {
		http.Error(w, err.Error(), http.StatusBadRequest)
		return
	}

	info, err := os.Stat(target)
	if err != nil {
		http.NotFound(w, r)
		return
	}

	if info.IsDir() {
		entries, err := os.ReadDir(target)
		if err != nil {
			http.Error(w, err.Error(), http.StatusInternalServerError)
			return
		}
		w.Header().Set("Content-Type", "text/plain; charset=utf-8")
		for _, e := range entries {
			name := e.Name()
			if e.IsDir() {
				name += "/"
			}
			fmt.Fprintln(w, name)
		}
		return
	}

	http.ServeFile(w, r, target)
}

func (s *server) handleCOPY(w http.ResponseWriter, r *http.Request) {
	src, err := s.resolveRequestPath(r.URL.Path)
	if err != nil {
		http.Error(w, err.Error(), http.StatusBadRequest)
		return
	}

	dst, err := s.resolveDestination(r)
	if err != nil {
		http.Error(w, err.Error(), http.StatusBadRequest)
		return
	}

	if err := copyOrMove(src, dst, false, overwriteAllowed(r.Header.Get("Overwrite"))); err != nil {
		writeCopyMoveError(w, err)
		return
	}

	w.WriteHeader(http.StatusCreated)
}

func (s *server) handleMOVE(w http.ResponseWriter, r *http.Request) {
	src, err := s.resolveRequestPath(r.URL.Path)
	if err != nil {
		http.Error(w, err.Error(), http.StatusBadRequest)
		return
	}

	dst, err := s.resolveDestination(r)
	if err != nil {
		http.Error(w, err.Error(), http.StatusBadRequest)
		return
	}

	if err := copyOrMove(src, dst, true, overwriteAllowed(r.Header.Get("Overwrite"))); err != nil {
		writeCopyMoveError(w, err)
		return
	}

	w.WriteHeader(http.StatusCreated)
}

func (s *server) handleDELETE(w http.ResponseWriter, r *http.Request) {
	target, err := s.resolveRequestPath(r.URL.Path)
	if err != nil {
		http.Error(w, err.Error(), http.StatusBadRequest)
		return
	}

	rootAbs, _ := filepath.Abs(s.root)
	targetAbs, _ := filepath.Abs(target)
	if rootAbs == targetAbs {
		http.Error(w, "refusing to delete storage root", http.StatusForbidden)
		return
	}

	if _, err := os.Stat(target); err != nil {
		http.NotFound(w, r)
		return
	}

	if err := os.RemoveAll(target); err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}

	w.WriteHeader(http.StatusNoContent)
}

func overwriteAllowed(v string) bool {
	return strings.ToUpper(strings.TrimSpace(v)) != "F"
}

func writeCopyMoveError(w http.ResponseWriter, err error) {
	switch {
	case errors.Is(err, os.ErrNotExist):
		http.Error(w, err.Error(), http.StatusNotFound)
	case strings.Contains(err.Error(), "destination exists"):
		http.Error(w, err.Error(), http.StatusPreconditionFailed)
	case strings.Contains(err.Error(), "parent does not exist"):
		http.Error(w, err.Error(), http.StatusConflict)
	default:
		http.Error(w, err.Error(), http.StatusInternalServerError)
	}
}

func copyOrMove(src, dst string, move bool, overwrite bool) error {
	srcInfo, err := os.Stat(src)
	if err != nil {
		return err
	}

	dstParent := filepath.Dir(dst)
	parentInfo, err := os.Stat(dstParent)
	if err != nil || !parentInfo.IsDir() {
		return fmt.Errorf("destination parent does not exist")
	}

	if _, err := os.Stat(dst); err == nil {
		if !overwrite {
			return fmt.Errorf("destination exists and overwrite is disabled")
		}
		if err := os.RemoveAll(dst); err != nil {
			return err
		}
	}

	if move {
		if err := os.Rename(src, dst); err == nil {
			return nil
		} else if !errors.Is(err, syscall.EXDEV) {
			// fallback anyway for portability
		}
	}

	if srcInfo.IsDir() {
		if err := copyDir(src, dst); err != nil {
			return err
		}
	} else {
		if err := copyFile(src, dst, srcInfo.Mode()); err != nil {
			return err
		}
	}

	if move {
		return os.RemoveAll(src)
	}
	return nil
}

func copyFile(src, dst string, mode os.FileMode) error {
	in, err := os.Open(src)
	if err != nil {
		return err
	}
	defer in.Close()

	out, err := os.OpenFile(dst, os.O_CREATE|os.O_WRONLY|os.O_TRUNC, mode)
	if err != nil {
		return err
	}
	defer out.Close()

	if _, err := io.Copy(out, in); err != nil {
		return err
	}

	return out.Close()
}

func copyDir(src, dst string) error {
	srcInfo, err := os.Stat(src)
	if err != nil {
		return err
	}

	if err := os.MkdirAll(dst, srcInfo.Mode()); err != nil {
		return err
	}

	return filepath.Walk(src, func(current string, info os.FileInfo, walkErr error) error {
		if walkErr != nil {
			return walkErr
		}
		if current == src {
			return nil
		}

		rel, err := filepath.Rel(src, current)
		if err != nil {
			return err
		}
		target := filepath.Join(dst, rel)

		if info.IsDir() {
			return os.MkdirAll(target, info.Mode())
		}

		return copyFile(current, target, info.Mode())
	})
}
