﻿using System;
using System.IO;
using System.Linq;
using Espera.Core.Audio;
using Rareform.IO;

namespace Espera.Core
{
    public class LocalSong : Song
    {
        /// <summary>
        /// Gets a value indicating whether this song is from a removable drive.
        /// </summary>
        /// <value>
        /// 	<c>true</c> if this song is from a removable drive; otherwise, <c>false</c>.
        /// </value>
        public bool IsRemovable
        {
            get
            {
                string songDrive = Path.GetPathRoot(this.OriginalPath);

                return DriveInfo.GetDrives()
                    .Where(drive => drive.DriveType == DriveType.Fixed)
                    .All(drive => drive.RootDirectory.Name != songDrive);
            }
        }

        public override bool HasToCache
        {
            get { return this.IsRemovable; }
        }

        /// <summary>
        /// Initializes a new instance of the <see cref="LocalSong"/> class.
        /// </summary>
        /// <param name="path">The path of the file.</param>
        /// <param name="audioType">The audio type.</param>
        /// <param name="duration">The duration of the song.</param>
        public LocalSong(string path, AudioType audioType, TimeSpan duration)
            : base(path, audioType, duration)
        {
            if (this.IsRemovable)
            {
                this.StreamingPath = this.OriginalPath;
            }
        }

        public override AudioPlayer CreateAudioPlayer()
        {
            return new LocalAudioPlayer();
        }

        public override void LoadToCache()
        {
            try
            {
                this.LoadToTempFile();
                this.IsCached = true;
                this.OnCachingCompleted(EventArgs.Empty);
            }

            catch (IOException)
            {
                this.OnCachingFailed(EventArgs.Empty);
            }
        }

        private void LoadToTempFile()
        {
            string path = Path.GetTempFileName();

            using (Stream sourceStream = File.OpenRead(this.OriginalPath))
            {
                using (Stream targetStream = File.OpenWrite(path))
                {
                    var operation = new StreamCopyOperation(sourceStream, targetStream);

                    operation.CopyProgressChanged += (sender, e) => this.OnCachingProgressChanged(e);

                    operation.Execute();
                }
            }

            this.StreamingPath = path;
        }
    }
}