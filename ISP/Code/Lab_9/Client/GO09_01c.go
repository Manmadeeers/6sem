package main

import (
	"bytes"
	"fmt"
	"io"
	"log"
	"net/http"
	"net/url"
	"strings"
	"time"
)

type Client struct {
	BaseURL    string
	Username   string
	Password   string
	HTTPClient *http.Client
}

func NewClient(baseURL, username, password string) *Client {
	return &Client{
		BaseURL:  strings.TrimRight(baseURL, "/"),
		Username: username,
		Password: password,
		HTTPClient: &http.Client{
			Timeout: 30 * time.Second,
		},
	}
}

func EscapePath(path string) string {
	parts := strings.Split(path, "/")
	for i, p := range parts {
		parts[i] = url.PathEscape(p)
	}
	return strings.Join(parts, "/")
}

func normalizeCollectionPath(path string) string {
	path = strings.Trim(path, "/")
	if path == "" {
		return ""
	}
	return path + "/"
}

func (c *Client) buildURL(remotePath string) string {
	remotePath = strings.TrimLeft(remotePath, "/")
	return c.BaseURL + "/" + EscapePath(remotePath)
}

func (c *Client) doRequest(method, remotePath string, body io.Reader, extraHeaders map[string]string) (*http.Response, error) {
	req, err := http.NewRequest(method, c.buildURL(remotePath), body)
	if err != nil {
		return nil, err
	}

	req.SetBasicAuth(c.Username, c.Password)

	for k, v := range extraHeaders {
		req.Header.Set(k, v)
	}

	resp, err := c.HTTPClient.Do(req)
	if err != nil {
		return nil, err
	}

	if resp.StatusCode < 200 || resp.StatusCode >= 300 {
		defer resp.Body.Close()
		respBody, _ := io.ReadAll(resp.Body)
		return nil, fmt.Errorf("%s %s failed: %s: %s", method, remotePath, resp.Status, strings.TrimSpace(string(respBody)))
	}

	return resp, nil
}

func (c *Client) MKCOL(remotePath string) error {
	resp, err := c.doRequest("MKCOL", normalizeCollectionPath(remotePath), nil, nil)
	if err != nil {
		return err
	}
	defer resp.Body.Close()
	return nil
}

func (c *Client) PUT(remotePath string, data []byte) error {
	headers := map[string]string{
		"Content-Type": "application/octet-stream",
	}
	resp, err := c.doRequest("PUT", remotePath, bytes.NewReader(data), headers)
	if err != nil {
		return err
	}
	defer resp.Body.Close()
	return nil
}

func (c *Client) GET(remotePath string) ([]byte, error) {
	resp, err := c.doRequest("GET", remotePath, nil, nil)
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close()

	return io.ReadAll(resp.Body)
}

func (c *Client) COPY(sourcePath, destinationPath string, overwrite bool) error {
	headers := map[string]string{
		"Destination": c.buildURL(destinationPath),
		"Overwrite":   boolToWebDAV(overwrite),
	}
	resp, err := c.doRequest("COPY", sourcePath, nil, headers)
	if err != nil {
		return err
	}
	defer resp.Body.Close()
	return nil
}

func (c *Client) MOVE(sourcePath, destinationPath string, overwrite bool) error {
	headers := map[string]string{
		"Destination": c.buildURL(destinationPath),
		"Overwrite":   boolToWebDAV(overwrite),
	}
	resp, err := c.doRequest("MOVE", sourcePath, nil, headers)
	if err != nil {
		return err
	}
	defer resp.Body.Close()
	return nil
}

func (c *Client) DELETE(remotePath string) error {
	resp, err := c.doRequest("DELETE", remotePath, nil, nil)
	if err != nil {
		return err
	}
	defer resp.Body.Close()
	return nil
}

func boolToWebDAV(v bool) string {
	if v {
		return "T"
	}
	return "F"
}

func main() {
	client := NewClient(
		"http://localhost:8081/webdav",
		"webdavuser",
		"StrongPass!",
	)

	if err := client.MKCOL("demo/"); err != nil {
		log.Fatal(err)
	} else {
		log.Printf("demo collection created(MKCOL)")
	}

	if err := client.PUT("demo/hello.txt", []byte("hello from Go WebDAV client\n")); err != nil {
		log.Fatal(err)
	} else {
		log.Printf("hello.txt file created(PUT)")
	}

	data, err := client.GET("demo/hello.txt")
	if err != nil {
		log.Fatal(err)
	}
	fmt.Print("File contents(GET): ")
	fmt.Println(string(data))

	if err := client.COPY("demo/hello.txt", "demo/hello-copy.txt", true); err != nil {
		log.Fatal(err)
	} else {
		log.Print("File contents copied to hello-copy.txt(COPY)")
	}

	if err := client.MOVE("demo/hello-copy.txt", "demo/hello-moved.txt", true); err != nil {
		log.Fatal(err)
	} else {
		log.Print("File contents moved to hello-move.txt(MOVE)")
	}

	if err := client.DELETE("demo/hello-moved.txt"); err != nil {
		log.Fatal(err)
	} else {
		log.Print("hello.txt file removed(DELETE)")
	}
}
