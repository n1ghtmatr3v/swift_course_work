package main

import (
	"fmt"
	"io"
	"log"
	"net/http"
	"os"
	"path/filepath"
	"strings"
	"test/binary"
	"test/graph"
	"test/kdtree"
)

const (
	pbfPath      = "data/Moscow.osm.pbf"
	MoscowPBFURL = "https://download.bbbike.org/osm/bbbike/Moscow/Moscow.osm.pbf"
)

func main() {

	if err := ensurePBFFile(pbfPath); err != nil {
		log.Fatal(err)
	}

	log.Println("building graph...")

	g := graph.BuildGraphFromPBF(pbfPath)

	err := binary.SaveGraph("data/graph.bin", g)
	if err != nil {
		log.Fatal(err)
	}

	log.Println("graph.bin built successfully")

	log.Println("building kdtree...")

	points := make([]kdtree.KDPoint, len(g.LatE7))
	for i := 0; i < len(g.LatE7); i++ {
		points[i] = kdtree.KDPoint{
			Vertex: uint32(i),
			X:      g.LatE7[i],
			Y:      g.LonE7[i],
		}
	}

	root := kdtree.BuildKDtree(points, 0, len(points)-1, 0)

	err = binary.SaveKDtree(root, "data/kdtree.bin")
	if err != nil {
		log.Fatal(err)
	}

	log.Println("kdtree.bin built successfully")
}

func ensurePBFFile(path string) error {
	info, err := os.Stat(path)
	if err == nil {
		log.Printf("using existing %s (%.2f MB)", path, float64(info.Size())/(1024*1024))
		return nil
	}

	if os.IsNotExist(err) == false {
		return fmt.Errorf("failed to check %s: %w", path, err)
	}

	if err := os.MkdirAll(filepath.Dir(path), 0o755); err != nil {
		return fmt.Errorf("failed to create data directory: %w", err)
	}

	downloadURL := strings.TrimSpace(os.Getenv("OSM_PBF_URL"))
	if downloadURL == "" {
		downloadURL = MoscowPBFURL
	}

	log.Printf("%s not found, downloading from %s", path, downloadURL)

	if err := downloadFile(downloadURL, path); err != nil {
		return err
	}

	info, err = os.Stat(path)
	if err != nil {
		return fmt.Errorf("downloaded %s but failed to stat it: %w", path, err)
	}

	log.Printf("downloaded %s (%.2f MB)", path, float64(info.Size())/(1024*1024))
	return nil
}

func downloadFile(downloadURL string, destinationPath string) error {
	request, err := http.NewRequest(http.MethodGet, downloadURL, nil)
	if err != nil {
		return fmt.Errorf("failed to create download request: %w", err)
	}

	request.Header.Set("User-Agent", "gopath-updategraphs/1.0")

	response, err := http.DefaultClient.Do(request)
	if err != nil {
		return fmt.Errorf("failed to download %s: %w", downloadURL, err)
	}
	defer response.Body.Close()

	if response.StatusCode < 200 || response.StatusCode >= 300 {
		return fmt.Errorf("failed to download %s: status %d", downloadURL, response.StatusCode)
	}

	tempPath := destinationPath + ".download"
	file, err := os.Create(tempPath)
	if err != nil {
		return fmt.Errorf("failed to create %s: %w", tempPath, err)
	}

	if _, err := io.Copy(file, response.Body); err != nil {
		file.Close()
		_ = os.Remove(tempPath)
		return fmt.Errorf("failed to save %s: %w", tempPath, err)
	}

	if err := file.Close(); err != nil {
		_ = os.Remove(tempPath)
		return fmt.Errorf("failed to close %s: %w", tempPath, err)
	}

	if err := os.Rename(tempPath, destinationPath); err != nil {
		_ = os.Remove(tempPath)
		return fmt.Errorf("failed to move %s to %s: %w", tempPath, destinationPath, err)
	}

	return nil
}
